/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 11-18-2025
 * @last modified by	 : Daniel Belini
 **/
public with sharing class ProposalPendingController {
  private static final Map<Id, List<ProposalPendingDTO>> cache = new Map<Id, List<ProposalPendingDTO>>();

  public enum PendingStatus {
    Aguardando,
    Respondido,
    Aprovado,
    Recusado
  }

  private static final Map<PendingStatus, Integer> STATUS_TO_CODE = new Map<PendingStatus, Integer>{
    PendingStatus.Aguardando => 1,
    PendingStatus.Respondido => 2,
    PendingStatus.Aprovado => 3,
    PendingStatus.Recusado => 4
  };

  private static final Map<Integer, PendingStatus> CODE_TO_STATUS = new Map<Integer, PendingStatus>{
    1 => PendingStatus.Aguardando,
    2 => PendingStatus.Respondido,
    3 => PendingStatus.Aprovado,
    4 => PendingStatus.Recusado
  };

  private static final Map<PendingStatus, String> STATUS_TO_API_VALUE = new Map<PendingStatus, String>{
    PendingStatus.Aguardando => '1',
    PendingStatus.Respondido => '2',
    PendingStatus.Aprovado => '3',
    PendingStatus.Recusado => '4'
  };

  private static final Map<String, PendingStatus> VALUE_TO_STATUS = new Map<String, PendingStatus>{
    '1' => PendingStatus.Aguardando,
    '2' => PendingStatus.Respondido,
    '3' => PendingStatus.Aprovado,
    '4' => PendingStatus.Recusado,
    'Aguardando' => PendingStatus.Aguardando,
    'Respondido' => PendingStatus.Respondido,
    'Aprovado' => PendingStatus.Aprovado,
    'Recusado' => PendingStatus.Recusado
  };

  @AuraEnabled(cacheable=true)
  public static List<ProposalPendingDTO> getPendings(Id opportunityId) {
    if (opportunityId == null) {
      return new List<ProposalPendingDTO>();
    }

    List<ProposalPending__c> records = [
      SELECT
        Id,
        Name,
        Description__c,
        DocumentTypeId__c,
        DocumentTypeName__c,
        Status__c,
        Response__c,
        FileUrl__c,
        RespondedDate__c,
        CreatedDate,
        LastModifiedDate
      FROM ProposalPending__c
      WHERE Opportunity__c = :opportunityId
      ORDER BY CreatedDate DESC
    ];

    List<ProposalPendingDTO> dtos = toDTO(records);
    cache.put(opportunityId, dtos);
    return dtos;
  }

  @AuraEnabled(cacheable=true)
  public static List<EzeeConnectProposalPendingService.DocumentTypeOption> getDocumentTypes() {
    return EzeeConnectProposalPendingService.getDocumentTypes();
  }

  @AuraEnabled
  public static List<ProposalPendingDTO> createPendings(
    Id opportunityId,
    String pendingInputsJson
  ) {
    List<PendingInput> pendingInputs = new List<PendingInput>();

    if (!String.isBlank(pendingInputsJson)) {
      pendingInputs = (List<PendingInput>) JSON.deserialize(
        pendingInputsJson,
        List<PendingInput>.class
      );
    }

    System.debug(
      LoggingLevel.INFO,
      'ProposalPendingController.createPendings - payload: ' + pendingInputsJson
    );
    Opportunity opportunity = loadOpportunity(opportunityId);

    if (pendingInputs == null || pendingInputs.isEmpty()) {
      throw new AuraHandledException(
        'Inclua ao menos uma pendência antes de salvar.'
      );
    }

    List<ProposalPending__c> recordsToInsert = new List<ProposalPending__c>();

    for (PendingInput input : pendingInputs) {
      validateInput(input);

      ProposalPending__c record = new ProposalPending__c();
      record.Opportunity__c = opportunity.Id;
      record.Description__c = input.description != null
        ? input.description.trim()
        : null;
      Boolean requireDocument = input.requestDocument == null
        ? true
        : input.requestDocument;
      record.DocumentTypeId__c = requireDocument ? input.documentTypeId : null;
      record.DocumentTypeName__c = requireDocument
        ? input.documentTypeName
        : null;
      record.Status__c = getStatusValue(PendingStatus.Aguardando);
      recordsToInsert.add(record);
    }

    Savepoint sp = Database.setSavepoint();

    try {
      insert recordsToInsert;
      enqueueSend(recordsToInsert);
    } catch (Exception e) {
      Database.rollback(sp);
      throw new AuraHandledException(
        'Erro ao enviar pendências para o aplicativo: ' + e.getMessage()
      );
    }

    List<ProposalPendingDTO> inserted = toDTO(
      [
        SELECT
          Id,
          Name,
          Description__c,
          DocumentTypeId__c,
          DocumentTypeName__c,
          Status__c,
          Response__c,
          FileUrl__c,
          RespondedDate__c,
          CreatedDate,
          LastModifiedDate
        FROM ProposalPending__c
        WHERE Id IN :recordsToInsert
      ]
    );

    cache.remove(opportunity.Id);

    return inserted;
  }

  @AuraEnabled
  public static ProposalPendingDTO updatePendingStatus(
    Id pendingId,
    String status,
    String descriptionRejected
  ) {
    System.debug(
      'ProposalPendingController.updatePendingStatus - payload: pendingId=' +
        pendingId +
        ', status=' +
        status +
        ', descriptionRejected=' +
        descriptionRejected
    );
    if (pendingId == null) {
      throw new AuraHandledException(
        'Informe a pendência que deseja atualizar.'
      );
    }

    if (String.isBlank(status)) {
      throw new AuraHandledException('Selecione o novo status.');
    }

    PendingStatus statusEnum = parseStatus(status);
    String normalizedReason = descriptionRejected != null
      ? descriptionRejected.trim()
      : null;
    if (
      statusEnum == PendingStatus.Recusado && String.isBlank(normalizedReason)
    ) {
      throw new AuraHandledException('Informe o motivo da recusa.');
    }

    ProposalPending__c pending = [
      SELECT
        Id,
        Status__c,
        Opportunity__r.IdVirtualOffice__c,
        Opportunity__c,
        FileUrl__c,
        Description__c,
        Name
      FROM ProposalPending__c
      WHERE Id = :pendingId
      LIMIT 1
    ];

    if (String.isBlank(pending.Opportunity__r.IdVirtualOffice__c)) {
      throw new AuraHandledException(
        'A oportunidade não possui o campo "ID Virtual Office" preenchido.'
      );
    }

    Savepoint sp = Database.setSavepoint();

    try {
      pending.Status__c = getStatusValue(statusEnum);
      if (statusEnum == PendingStatus.Recusado) {
        pending.Response__c = normalizedReason;
      }
      update pending;
      enqueueStatusUpdate(pending.Id, status, normalizedReason);
      if (statusEnum == PendingStatus.Aprovado) {
        linkAttachmentToOpportunity(pending);
      }
    } catch (Exception e) {
      Database.rollback(sp);
      throw new AuraHandledException(
        'Não foi possível atualizar o status da pendência: ' + e.getMessage()
      );
    }

    ProposalPending__c refreshed = [
      SELECT
        Id,
        Name,
        Description__c,
        DocumentTypeId__c,
        DocumentTypeName__c,
        Status__c,
        Response__c,
        FileUrl__c,
        RespondedDate__c,
        CreatedDate,
        LastModifiedDate
      FROM ProposalPending__c
      WHERE Id = :pending.Id
      LIMIT 1
    ];

    cache.remove(pending.Opportunity__r.Id);

    return toDTO(new List<ProposalPending__c>{ refreshed })[0];
  }

  @TestVisible
  static void enqueueSend(List<ProposalPending__c> records) {
    if (records == null || records.isEmpty()) {
      return;
    }
    List<Id> ids = new List<Id>();
    for (ProposalPending__c record : records) {
      if (record.Id != null) {
        ids.add(record.Id);
      }
    }
    if (!ids.isEmpty()) {
      System.enqueueJob(new ProposalPendingSendQueueable(ids));
    }
  }

  @TestVisible
  static void enqueueStatusUpdate(
    Id pendingId,
    String status,
    String descriptionRejected
  ) {
    if (pendingId == null || String.isBlank(status)) {
      return;
    }
    System.enqueueJob(
      new ProposalPendingStatusQueueable(pendingId, status, descriptionRejected)
    );
  }

  private static Opportunity loadOpportunity(Id opportunityId) {
    if (opportunityId == null) {
      throw new AuraHandledException('Informe a oportunidade.');
    }

    Opportunity opportunity = [
      SELECT Id, IdVirtualOffice__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];

    if (String.isBlank(opportunity.IdVirtualOffice__c)) {
      throw new AuraHandledException(
        'Preencha o campo "ID Virtual Office" antes de criar uma pendência.'
      );
    }

    return opportunity;
  }

  private static void validateInput(PendingInput input) {
    if (input == null) {
      throw new AuraHandledException('Registro de pendência inválido.');
    }

    if (String.isBlank(input.description)) {
      System.debug(
        LoggingLevel.ERROR,
        'Descrição vazia detectada em pending input: ' + JSON.serialize(input)
      );
      throw new AuraHandledException('A descrição é obrigatória.');
    }

    Boolean requireDocument = input.requestDocument == null
      ? true
      : input.requestDocument;

    if (requireDocument && input.documentTypeId == null) {
      throw new AuraHandledException(
        'Selecione o tipo de documento para pendências que solicitarem arquivo.'
      );
    }

    if (!requireDocument) {
      input.documentTypeId = null;
      input.documentTypeName = null;
    }
  }

  private static void linkAttachmentToOpportunity(ProposalPending__c pending) {
    if (
      pending == null ||
      pending.Opportunity__c == null ||
      String.isBlank(pending.FileUrl__c)
    ) {
      return;
    }
    try {
      OpportunityAttachmentLinkService.AttachmentInput input = new OpportunityAttachmentLinkService.AttachmentInput();
      input.opportunityId = pending.Opportunity__c;
      input.attachmentUrl = pending.FileUrl__c;
      input.externalId = pending.Id;
      input.type = 'Other';
      input.description = String.isNotBlank(pending.Description__c)
        ? pending.Description__c
        : pending.Name;
      OpportunityAttachmentLinkService.upsertAttachment(input);
    } catch (Exception e) {
      Utils.createLog(
        'ProposalPendingController',
        'linkAttachmentToOpportunity ' + pending.Id,
        e
      );
    }
  }

  private static List<ProposalPendingDTO> toDTO(
    List<ProposalPending__c> records
  ) {
    List<ProposalPendingDTO> results = new List<ProposalPendingDTO>();

    for (ProposalPending__c record : records) {
      ProposalPendingDTO dto = new ProposalPendingDTO();
      PendingStatus statusEnum;
      try {
        statusEnum = parseStatus(record.Status__c);
      } catch (Exception e) {
        statusEnum = null;
      }
      dto.id = record.Id;
      dto.name = record.Name;
      dto.description = record.Description__c;
      dto.documentTypeId = record.DocumentTypeId__c != null
        ? Integer.valueOf(record.DocumentTypeId__c.intValue())
        : null;
      dto.documentTypeName = record.DocumentTypeName__c;
      dto.status = statusEnum != null ? statusEnum.name() : record.Status__c;
      dto.response = record.Response__c;
      dto.fileUrl = record.FileUrl__c;
      dto.respondedDate = record.RespondedDate__c;
      dto.createdDate = record.CreatedDate;
      dto.lastModifiedDate = record.LastModifiedDate;
      results.add(dto);
    }

    return results;
  }

  public class PendingInput {
    @AuraEnabled
    public String description;
    @AuraEnabled
    public Integer documentTypeId;
    @AuraEnabled
    public String documentTypeName;
    @AuraEnabled
    public Boolean requestDocument;
  }

  public class ProposalPendingDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public Integer documentTypeId;
    @AuraEnabled
    public String documentTypeName;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String response;
    @AuraEnabled
    public String fileUrl;
    @AuraEnabled
    public Datetime respondedDate;
    @AuraEnabled
    public Datetime createdDate;
    @AuraEnabled
    public Datetime lastModifiedDate;
  }

  public static PendingStatus parseStatus(String value) {
    PendingStatus status = VALUE_TO_STATUS.get(value);
    if (status == null) {
      throw new AuraHandledException('Status inválido informado: ' + value);
    }
    return status;
  }

  public static Integer getStatusCode(PendingStatus status) {
    Integer code = STATUS_TO_CODE.get(status);
    if (code == null) {
      throw new AuraHandledException(
        'Status não suportado para integração: ' + status
      );
    }
    return code;
  }

  public static PendingStatus getStatusByCode(Integer code) {
    PendingStatus status = CODE_TO_STATUS.get(code);
    if (status == null) {
      throw new AuraHandledException('Código de status não suportado: ' + code);
    }
    return status;
  }

  public static String getStatusValue(PendingStatus status) {
    String value = STATUS_TO_API_VALUE.get(status);
    if (value == null) {
      throw new AuraHandledException(
        'Valor de picklist não encontrado para o status: ' + status
      );
    }
    return value;
  }
}
