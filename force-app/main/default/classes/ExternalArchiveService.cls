/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : AdditionalCoverageNewClassesTest, ExternalArchiveServiceTest
 **/
public with sharing class ExternalArchiveService {
  public class UploadResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public Id attachmentId;
  }

  /**
   * Envia um arquivo para o endpoint proposal/ExternalArchive e cria registro em OpportunityAttachmentLink__c.
   */
  @AuraEnabled
  public static UploadResult uploadExternalArchive(
    Id opportunityId,
    String fileName,
    String base64File,
    String sobjectId,
    String activityName,
    String docRequiredName
  ) {
    if (String.isBlank(base64File)) {
      throw new AuraHandledException('Arquivo inválido.');
    }
    if (String.isBlank(sobjectId)) {
      throw new AuraHandledException('Registro relacionado é obrigatório.');
    }

    Boolean isRelatorio = isRelatorioFinalDeObra(activityName);
    String fileNameWithExtension = isRelatorio
      ? normalizeFileName(fileName)
      : ensureExtension(fileName);

    if (opportunityId == null) {
      throw new AuraHandledException('Oportunidade é obrigatória.');
    }

    Opportunity opp = [
      SELECT Id, IdVirtualOffice__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
    if (String.isBlank(opp.IdVirtualOffice__c)) {
      throw new AuraHandledException(
        'IdVirtualOffice__c não está preenchido na oportunidade.'
      );
    }

    Integrador__mdt integracao = [
      SELECT URL__c
      FROM Integrador__mdt
      WHERE DeveloperName = 'ExternalArchive'
      LIMIT 1
    ];

    Map<String, Object> body = new Map<String, Object>{
      'IdProposal' => opp.IdVirtualOffice__c,
      'FileBase64' => base64File,
      'FileName' => fileNameWithExtension
    };

    System.debug('Body: ' + JSON.serialize(body));
    HttpRequest req = new HttpRequest();
    System.debug('Endpoint: ' + integracao.URL__c);
    req.setEndpoint(integracao.URL__c);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setBody(JSON.serialize(body));
    System.debug('body: ' + JSON.serialize(body));

    HttpResponse res = Utils.callIntegrationNivello(req);

    if (
      res == null ||
      res.getStatusCode() < 200 ||
      res.getStatusCode() >= 300
    ) {
      UploadResult result = new UploadResult();
      result.success = false;
      result.message =
        'Erro ao enviar arquivo: ' +
        (res != null
          ? res.getStatusCode() + ' - ' + res.getBody()
          : 'sem resposta');
      return result;
    }

    String internalUrl;
    String contentDocumentId;
    if (isRelatorio) {
      Blob fileBlob = decodeBase64File(base64File);
      String title = stripExtension(fileNameWithExtension);
      ContentVersion cv = new ContentVersion();
      cv.ContentLocation = 'S';
      cv.FirstPublishLocationId = (Id) sobjectId;
      cv.VersionData = fileBlob;
      cv.Title = title;
      cv.PathOnClient = fileNameWithExtension;
      cv.IsMajorVersion = true;
      insert cv;

      cv = [
        SELECT Id, ContentDocumentId
        FROM ContentVersion
        WHERE Id = :cv.Id
        LIMIT 1
      ];
      contentDocumentId = String.valueOf(cv.ContentDocumentId);
      internalUrl =
        '/sfc/servlet.shepherd/document/download/' + cv.ContentDocumentId;
    }

    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c();
    // link.OpportunityId__c = opportunityId;
    link.ActivityName__c = activityName;
    link.SObjectId__c = sobjectId;
    link.AttachmentDescription__c = fileNameWithExtension;
    link.DocRequiredName__c = docRequiredName;
    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
      res.getBody()
    );
    link.AttachmentURL__c = (String) responseBody.get('data');
    if (isRelatorio) {
      link.ContentDocumentId__c = contentDocumentId;
      link.InternalAttachmentURL__c = internalUrl;
    }
    insert link;

    UploadResult ok = new UploadResult();
    ok.success = true;
    ok.attachmentId = link.Id;
    ok.message = 'Arquivo enviado com sucesso.';
    return ok;
  }

  /**
   * Versão sem Opportunity — usa caseId como sobjectId e IdVirtualOffice__c do Case via lookup dinâmico.
   * Se não houver Oportunidade vinculada, lança exceção descritiva.
   */
  @AuraEnabled
  public static UploadResult uploadExternalArchiveForCase(
    Id caseId,
    String fileName,
    String base64File,
    String activityName,
    String docRequiredName
  ) {
    if (String.isBlank(base64File)) {
      throw new AuraHandledException('Arquivo inválido.');
    }
    if (caseId == null) {
      throw new AuraHandledException('caseId é obrigatório.');
    }

    Case c = [
      SELECT Id, Oportunidade_Pai__c, Oportunidade_Pai__r.IdVirtualOffice__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];

    Id opportunityId = c.Oportunidade_Pai__c;
    String virtualOfficeId = c.Oportunidade_Pai__r != null
      ? c.Oportunidade_Pai__r.IdVirtualOffice__c
      : null;

    // Sem Oportunidade: usa o próprio caseId como IdProposal na API
    String idProposal = String.isNotBlank(virtualOfficeId)
      ? virtualOfficeId
      : String.valueOf(caseId);

    return uploadExternalArchiveWithIdProposal(
      idProposal,
      opportunityId,
      fileName,
      base64File,
      caseId,
      activityName,
      docRequiredName
    );
  }

  private static UploadResult uploadExternalArchiveWithIdProposal(
    String idProposal,
    Id opportunityId,
    String fileName,
    String base64File,
    Id sobjectId,
    String activityName,
    String docRequiredName
  ) {
    Boolean isRelatorio = isRelatorioFinalDeObra(activityName);
    String fileNameWithExtension = isRelatorio
      ? normalizeFileName(fileName)
      : ensureExtension(fileName);

    Integrador__mdt integracao = [
      SELECT URL__c
      FROM Integrador__mdt
      WHERE DeveloperName = 'ExternalArchive'
      LIMIT 1
    ];

    Map<String, Object> body = new Map<String, Object>{
      'IdProposal' => idProposal,
      'FileBase64' => base64File,
      'FileName' => fileNameWithExtension
    };

    HttpRequest req = new HttpRequest();
    req.setEndpoint(integracao.URL__c);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setBody(JSON.serialize(body));

    HttpResponse res = Utils.callIntegrationNivello(req);

    if (
      res == null ||
      res.getStatusCode() < 200 ||
      res.getStatusCode() >= 300
    ) {
      UploadResult result = new UploadResult();
      result.success = false;
      result.message =
        'Erro ao enviar arquivo: ' +
        (res != null
          ? res.getStatusCode() + ' - ' + res.getBody()
          : 'sem resposta');
      return result;
    }

    String internalUrl;
    String contentDocumentId;
    if (isRelatorio && opportunityId != null) {
      Blob fileBlob = decodeBase64File(base64File);
      String title = stripExtension(fileNameWithExtension);
      ContentVersion cv = new ContentVersion();
      cv.ContentLocation = 'S';
      cv.FirstPublishLocationId = (Id) sobjectId;
      cv.VersionData = fileBlob;
      cv.Title = title;
      cv.PathOnClient = fileNameWithExtension;
      cv.IsMajorVersion = true;
      insert cv;
      cv = [
        SELECT Id, ContentDocumentId
        FROM ContentVersion
        WHERE Id = :cv.Id
        LIMIT 1
      ];
      contentDocumentId = String.valueOf(cv.ContentDocumentId);
      internalUrl =
        '/sfc/servlet.shepherd/document/download/' + cv.ContentDocumentId;
    }

    OpportunityAttachmentLink__c link = new OpportunityAttachmentLink__c();
    link.ActivityName__c = activityName;
    link.SObjectId__c = String.valueOf(sobjectId);
    link.AttachmentDescription__c = fileNameWithExtension;
    link.DocRequiredName__c = docRequiredName;
    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
      res.getBody()
    );
    link.AttachmentURL__c = (String) responseBody.get('data');
    if (isRelatorio && String.isNotBlank(contentDocumentId)) {
      link.ContentDocumentId__c = contentDocumentId;
      link.InternalAttachmentURL__c = internalUrl;
    }
    insert link;

    UploadResult ok = new UploadResult();
    ok.success = true;
    ok.attachmentId = link.Id;
    ok.message = 'Arquivo enviado com sucesso.';
    return ok;
  }

  private static Boolean isRelatorioFinalDeObra(String activityName) {
    return TaskUtils.isRelatorioExecucaoDeObraSubject(activityName);
  }

  private static Blob decodeBase64File(String base64File) {
    String content = base64File;
    Integer idx = content.indexOf('base64,');
    if (idx > -1) {
      content = content.substring(idx + 7);
    }
    return EncodingUtil.base64Decode(content);
  }

  private static String stripExtension(String name) {
    if (String.isBlank(name)) {
      return 'arquivo';
    }
    Integer idx = name.lastIndexOf('.');
    if (idx > 0) {
      return name.substring(0, idx);
    }
    return name;
  }

  private static String ensureExtension(String name) {
    if (String.isBlank(name)) {
      return 'arquivo.pdf';
    }
    if (name.contains('.')) {
      return name;
    }
    return name + '.pdf';
  }

  private static String normalizeFileName(String name) {
    if (String.isBlank(name)) {
      return 'arquivo';
    }
    return name;
  }
}
