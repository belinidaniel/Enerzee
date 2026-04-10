/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : IntegracaoNivelloPropostaTest, IntegracaoNivelloTest, ProposalEngineSupportTest
 **/
public with sharing class IntegracaoNivelloProposta {
  //Por razões de tamanho de pilha, esta classe processa apenas uma Oportunidade por vez

  public static ProposalIntegrationResult gerandoPropostaSincrona(Id oppId) {
    return gerandoPropostaInterna(oppId, null);
  }

  public static ProposalIntegrationResult gerandoPropostaSincrona(
    Id oppId,
    Id contentVersionId
  ) {
    return gerandoPropostaInterna(oppId, contentVersionId);
  }

  @future(callout=true)
  public static void gerandoProposta(Id oppId) {
    gerandoPropostaInterna(oppId, null);
  }

  @future(callout=true)
  public static void gerandoProposta(Id oppId, Id contentVersionId) {
    gerandoPropostaInterna(oppId, contentVersionId);
  }

  private static ProposalIntegrationResult gerandoPropostaInterna(
    Id oppId,
    Id contentVersionId
  ) {
    ProposalIntegrationResult result = new ProposalIntegrationResult();

    Opportunity opp = [
      SELECT
        Id,
        IdVirtualOffice__c,
        OwnerId,
        StatusBodyIntegracaoNivello__c,
        SucessoIntegracaoNivello__c,
        StageName,
        ValorTotalProposta__c,
        recordType.name
      FROM Opportunity
      WHERE Id = :oppId
      LIMIT 1
    ];

    ContentVersion proposalVersion = resolveProposalVersion(
      opp,
      contentVersionId
    );
    if (proposalVersion == null || proposalVersion.VersionData == null) {
      result.success = false;
      result.message = 'Nenhum arquivo de proposta encontrado para envio.';
      return result;
    }

    try {
      JSONGenerator gen = JSON.createGenerator(true);
      gen.writeStartObject();
      gen.writeStringField('id', opp.IdVirtualOffice__c);
      gen.writeBooleanField('approved', true);
      gen.writeNumberField(
        'opportunityPhase',
        StatusEnumMap.getStatusEnum(opp.recordType.Name, opp.StageName)
      );
      gen.writeNumberField(
        'proposalValue',
        opp.ValorTotalProposta__c == null ? 0 : opp.ValorTotalProposta__c
      );
      gen.writeStringField(
        'contract',
        'data:application/pdf;base64,' +
        EncodingUtil.base64Encode(proposalVersion.VersionData)
      );
      gen.writeEndObject();

      HttpResponse response = chamadaIntegracao(
        gen.getAsString(),
        'Gerando_Proposta',
        'POST',
        oppId,
        'gerandoProposta'
      );

      result.statusCode = response != null ? response.getStatusCode() : null;
      result.responseBody = response != null ? response.getBody() : null;

      if (response != null && response.getStatusCode() == 200) {
        handleAttachmentResponse(opp.Id, response);
        opp.SucessoIntegracaoNivello__c = true;
        opp.VerificarCamposElaboracao__c = false;
        opp.PropostaGerada__c = true;
        result.success = true;
        result.message = 'Proposta enviada para o aplicativo.';
      } else {
        opp.SucessoIntegracaoNivello__c = false;
        result.success = false;
        result.message = 'Falha ao enviar a proposta para o aplicativo.';
      }

      opp.StatusBodyIntegracaoNivello__c = response == null
        ? 'Sem resposta'
        : response.getStatusCode() + ' ' + response.getBody();

      OpportunityTriggerHandler.disableTrigger();
      try {
        update opp;
      } finally {
        OpportunityTriggerHandler.enableTrigger();
      }
    } catch (Exception e) {
      Utils.createLog('IntegracaoNivelloProposta', 'gerandoProposta', e, oppId);
      result.success = false;
      result.message = 'Falha ao enviar a proposta para o aplicativo.';
      result.responseBody = e.getMessage();
    }

    return result;
  }

  private static ContentVersion resolveProposalVersion(
    Opportunity opp,
    Id contentVersionId
  ) {
    if (contentVersionId != null) {
      List<ContentVersion> explicitVersion = [
        SELECT Id, VersionData, FileType, ContentSize, CreatedDate
        FROM ContentVersion
        WHERE Id = :contentVersionId
        LIMIT 1
      ];
      return explicitVersion.isEmpty() ? null : explicitVersion[0];
    }

    List<ContentDocumentLink> cdlList = [
      SELECT Id, ContentDocumentId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :opp.Id
    ];
    if (cdlList.isEmpty()) {
      return null;
    }

    List<Id> contentDocumentIds = new List<Id>();
    for (ContentDocumentLink cdl : cdlList) {
      contentDocumentIds.add(cdl.ContentDocumentId);
    }

    List<ContentVersion> proposalVersions;
    if (
      OpportunityUtils.isStatusAwaitingAcceptance(opp) &&
      OpportunityUtils.hasProposalReadjustment(opp)
    ) {
      proposalVersions = [
        SELECT Id, VersionData, FileType, ContentSize, CreatedDate
        FROM ContentVersion
        WHERE
          ContentDocumentId IN :contentDocumentIds
          AND FileType = 'PDF'
          AND IsProposal__c = TRUE
          AND (Title LIKE '%READEQUACAO%'
          OR Title LIKE '%READEQUAÇÃO%')
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];
    } else {
      proposalVersions = [
        SELECT Id, VersionData, FileType, ContentSize, CreatedDate
        FROM ContentVersion
        WHERE
          ContentDocumentId IN :contentDocumentIds
          AND FileType = 'PDF'
          AND IsProposal__c = TRUE
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];
    }

    return proposalVersions.isEmpty() ? null : proposalVersions[0];
  }

  @future(callout=true)
  public static void finalizacaoProposta(Set<Id> triggerIds) {
    Set<Id> contentDocumentIds = new Set<Id>();
    Map<Id, String> mapaArquivos64 = new Map<Id, String>();

    //Buscar os campos das Oportunidades a serem enviadas
    Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
      [
        SELECT Id, IdVirtualOffice__c, LastModifiedDate
        FROM Opportunity
        WHERE Id IN :triggerIds
      ]
    );

    //Buscar o conteúdo dos arquivos - apenas a última versão dos mesmos
    List<ContentVersion> arquivos = [
      SELECT Id, VersionData, FileType, FirstPublishLocationId
      FROM ContentVersion
      WHERE FirstPublishLocationId IN :triggerIds AND FileType = 'PDF'
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    //Montar o mapa contendo a chave Id da Oportunidade e o conteúdo base64 VersionData
    for (ContentVersion arquivo : arquivos) {
      //Pegar apenas o primeiro arquivo, no caso de haver mais de um
      if (!mapaArquivos64.keySet().contains(arquivo.FirstPublishLocationId)) {
        mapaArquivos64.put(
          arquivo.FirstPublishLocationId,
          EncodingUtil.base64Encode(arquivo.VersionData)
        );
      }
    }

    for (Opportunity opp : oppMap.values()) {
      //Garantir que há um arquivo a ser enviado
      if (mapaArquivos64.get(opp.Id) != null) {
        FinalizacaoPropostaRequest corpoRequisicao = new FinalizacaoPropostaRequest();
        corpoRequisicao.id = opp.IdVirtualOffice__c;
        corpoRequisicao.proposta = mapaArquivos64.get(opp.Id);

        String implementationDateAux = String.valueOf(opp.LastModifiedDate);
        implementationDateAux = implementationDateAux.replace(' ', 'T');
        implementationDateAux += '.' + opp.LastModifiedDate.millisecond() + 'Z';

        corpoRequisicao.implementationDate = implementationDateAux;
        HttpResponse response = chamadaIntegracao(
          JSON.serialize(corpoRequisicao),
          'Finalizacao_Proposta',
          'POST',
          opp.Id,
          'finalizacaoProposta'
        );

        //Sucesso
        if (response.getStatusCode() == 200) {
          System.debug('SUCCESS');
          opp.SucessoIntegracaoNivello__c = true;
        }
        //Erro
        else {
          System.debug('ERROR');
          opp.SucessoIntegracaoNivello__c = false;
        }
        opp.StatusBodyIntegracaoNivello__c =
          response.getStatusCode() +
          ' ' +
          response.getBody();
      }
    }
    OpportunityTriggerHandler.disableTrigger();
    update oppMap.values();
    OpportunityTriggerHandler.enableTrigger();
  }

  @future(callout=true)
  public static void sendUrlSimulation(Set<Id> opportunityIds) {
    // Buscar os campos das Oportunidades a serem enviadas
    List<Opportunity> oppList = [
      SELECT Id, IdVirtualOffice__c, URLSimulation__c
      FROM Opportunity
      WHERE Id IN :opportunityIds
    ];

    for (Opportunity opp : oppList) {
      try {
        URLSimulationRequest request = new URLSimulationRequest();
        request.Id = opp.IdVirtualOffice__c;
        request.urlSimulation = opp.URLSimulation__c;

        HttpResponse res = chamadaIntegracao(
          JSON.serialize(request),
          'Envia_URLSimulacao',
          'PATCH',
          opp.Id,
          'sendUrlSimulation'
        );

        // Handle the response
        if (res.getStatusCode() == 200) {
          //System.debug('Request successful');
        } else {
          //System.debug('Request failed: ' + res.getStatus());
        }
      } catch (Exception e) {
        Utils.createLog(
          'IntegracaoNivelloProposta',
          'Exception in sendUrlSimulation',
          e,
          opp.Id
        );
      }
    }
  }

  private static HttpResponse chamadaIntegracao(
    String body,
    String integracaoProposta,
    String method,
    Id relatedId,
    String logMethodName
  ) {
    Integrador__mdt parametrosIntegracao = [
      SELECT Id, URL__c
      FROM Integrador__mdt
      WHERE DeveloperName = :integracaoProposta
    ];

    Http httpObj = new Http();
    HttpRequest request = new HttpRequest();

    System.debug('parametrosIntegracao');
    System.debug(parametrosIntegracao.URL__c);
    System.debug(body);
    request.setEndpoint(parametrosIntegracao.URL__c);
    request.setMethod(method);
    request.setTimeout(120000);
    request.setHeader('Content-Type', 'application/json');
    request.setBody(body);

    HttpResponse response = Utils.callIntegrationNivello(request);

    Utils.LogDTO logDTO = new Utils.LogDTO();
    logDTO.className = 'IntegracaoNivelloProposta';
    logDTO.methodName = String.isNotBlank(logMethodName)
      ? logMethodName
      : integracaoProposta;
    logDTO.relatedId = relatedId;
    logDTO.httpMethod = method;
    logDTO.requestBody = body;
    logDTO.requestURI = parametrosIntegracao.URL__c;
    if (response != null) {
      logDTO.statusCode = response.getStatusCode();
      logDTO.status = response.getStatus();
      logDTO.responseBody = response.getBody();
    }
    Utils.createLog(logDTO);

    return response;
  }

  /*public static integer getStatusEnum(String stageName){
							 if(stageName == OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA){
											 return 4;
							 }else if (	 stageName == OpportunityUtils.STATUS_AGENDAMENTO_DA_VISITA_TECNICA || 
																			 stageName == OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE){
											 return 6;
							 }else if(stageName == OpportunityUtils.STATUS_READEQUACAO_DE_PROPOSTA){
											 return 7;
							 }else if(stageName == OpportunityUtils.STATUS_METODO_DE_PAGAMENTO){
											 return 5;
							 }else if(stageName == OpportunityUtils.STATUS_GANHO_FECHADO){
											 return 10;
							 }else if(stageName == OpportunityUtils.STATUS_VALIDACAO_DO_METODO_DE_PAGAMENTO){
											 return 13;
							 }else if(stageName == OpportunityUtils.STATUS_PROPOSTA_ENVIADA_AGUARDANDO_ACEITE){
											 return 4;
							 }else if(stageName == OpportunityUtils.STATUS_GANHO_FECHADO){
											 return 4;
							 }else if(stageName == OpportunityUtils.STATUS_CONTRATO_ENVIADO){
											 return 7;
							 }else if(stageName == OpportunityUtils.STATUS_CONTRATO_FIRMADO_ASSINADO){
											 return 4;
							 }else{
											 return 0;
							 }
			 }*/

  public class GerandoPropostaRequest {
    public Boolean approved; // true
    public String id; // "3fa85f64-5717-4562-b3fc-2c963f66afa6"
    public String description; //	 "string"
    public String contract; //	 Blob da proposta. O nome é "contract" mesmo pois a API foi criada assim
  }

  public class FinalizacaoPropostaRequest {
    public String id; // "3fa85f64-5717-4562-b3fc-2c963f66afa6"
    public String implementationDate; // "2022-06-09T00:19:29.477Z"
    public String proposta; //	 Blob da proposta
  }

  public class URLSimulationRequest {
    public String Id { get; set; }
    public String urlSimulation { get; set; }
  }

  public class ProposalIntegrationResult {
    public Boolean success = false;
    public Integer statusCode;
    public String message;
    public String responseBody;
    public String attachmentUrl;
  }

  private class ProposalResponse {
    public Boolean success;
    public ProposalAttachment data;
  }

  private class ProposalAttachment {
    public String id;
    public String urlFile;
  }

  private static Id handleAttachmentResponse(
    Id opportunityId,
    HttpResponse response
  ) {
    if (response == null || String.isBlank(response.getBody())) {
      return null;
    }

    try {
      Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
        response.getBody()
      );
      Map<String, Object> responseData = responseBody != null &&
        responseBody.containsKey('data') &&
        responseBody.get('data') instanceof Map<String, Object>
        ? (Map<String, Object>) responseBody.get('data')
        : null;

      Boolean success = responseBody != null &&
        responseBody.containsKey('success')
        ? Boolean.valueOf(String.valueOf(responseBody.get('success')))
        : true;
      String attachmentUrl = coalesce(
        getStringValue(responseData, 'urlFile'),
        getStringValue(responseData, 'fileUrl'),
        getStringValue(responseBody, 'urlFile')
      );
      String externalId = coalesce(
        getStringValue(responseData, 'id'),
        getStringValue(responseBody, 'id')
      );

      if (!success || String.isBlank(attachmentUrl)) {
        return null;
      }

      OpportunityAttachmentLinkService.AttachmentInput input = new OpportunityAttachmentLinkService.AttachmentInput();
      input.opportunityId = opportunityId;
      input.attachmentUrl = attachmentUrl;
      input.externalId = externalId;
      input.type = 'Proposal';

      String decodedFileName = extractFileName(attachmentUrl);
      if (String.isNotBlank(decodedFileName)) {
        input.description = decodedFileName;
      }

      OpportunityAttachmentLinkService.upsertAttachment(input);
      if (String.isNotBlank(input.externalId)) {
        OpportunityAttachmentLink__c saved = [
          SELECT Id
          FROM OpportunityAttachmentLink__c
          WHERE ExternalId__c = :input.externalId
          LIMIT 1
        ];
        return saved.Id;
      }
      return null;
    } catch (Exception e) {
      Utils.createLog(
        'IntegracaoNivelloProposta',
        'handleAttachmentResponse',
        e,
        opportunityId
      );
      return null;
    }
  }

  private static String extractFileName(String url) {
    if (String.isBlank(url)) {
      return null;
    }

    Integer lastSlash = url.lastIndexOf('/');
    String fileName = lastSlash != -1 &&
      lastSlash < url.length() - 1
      ? url.substring(lastSlash + 1)
      : url;

    try {
      return EncodingUtil.urlDecode(fileName, 'UTF-8');
    } catch (Exception e) {
      return fileName;
    }
  }

  private static String getStringValue(Map<String, Object> source, String key) {
    if (source == null || !source.containsKey(key) || source.get(key) == null) {
      return null;
    }
    return String.valueOf(source.get(key));
  }

  private static String coalesce(String firstValue, String secondValue) {
    return String.isNotBlank(firstValue) ? firstValue : secondValue;
  }

  private static String coalesce(
    String firstValue,
    String secondValue,
    String thirdValue
  ) {
    return String.isNotBlank(firstValue)
      ? firstValue
      : String.isNotBlank(secondValue) ? secondValue : thirdValue;
  }
}
