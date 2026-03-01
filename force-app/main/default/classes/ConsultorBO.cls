public with sharing class ConsultorBO {
  public static Id consultorRT = Schema.SObjectType.Consultor__c.getRecordTypeInfosByDeveloperName()
    .get('Consultor')
    .getRecordTypeId();

  public static void assignCPFCNPJToIdentificationNumber(
    List<Consultor__c> newRecordList
  ) {
    for (Consultor__c consultor : newRecordList) {
      if (consultor.NumeroIdentificacao__c == null) {
        consultor.NumeroIdentificacao__c = consultor.SeCPFouCNPJ__c;
      }
    }
  }

  public static void sendFornecedorRepresentanteRecordToSAP(
    List<Consultor__c> newRecordList
  ) {
    // Representante (SAP) = Consultor = Vendedor
    // Fornecedor (SAP) = Franqueado =  Integrador (DESCONTINUADA)

    User runningUser = [
      SELECT Id, Name, Profile.Name
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];

    if (!runningUser.Name.equalsIgnoreCase('Integrador SAP')) {
      Set<Id> representanteIds = new Set<Id>();
      Set<Id> fornecedorIds = new Set<Id>();
      for (Consultor__c consultor : newRecordList) {
        if (consultor.RecordTypeID == consultorRT) {
          representanteIds.add(consultor.Id);
          fornecedorIds.add(consultor.Id);
        }
      }

      if (!representanteIds.isEmpty()) {
        IntegracaoSAPRepresentante.sendRepresentante(representanteIds);
      }

      if (!fornecedorIds.isEmpty()) {
        IntegracaoSAPFornecedor.sendFornecedor(fornecedorIds);
      }
    }
  }

  public static void createMessagingUser(
    List<Consultor__c> consultores,
    Map<Id, Consultor__c> oldMap
  ) {
    try {
      List<MessagingEndUser> messagingUsers = new List<MessagingEndUser>();
      Map<String, Consultor__c> consultantByPhone = new Map<String, Consultor__c>();
      Id channelPartnerId = MessagingEndUserService.resolveChannelId(
        '+55 11 4003-8852'
      );

      for (Consultor__c consultant : consultores) {
        if (String.isBlank(consultant.Telefone__c)) {
          continue;
        }

        Consultor__c oldConsultant = oldMap.get(consultant.Id);

        if (
          oldConsultant != null &&
          (oldConsultant.Telefone__c == consultant.Telefone__c)
        )
          continue;

        consultantByPhone.put(consultant.Telefone_Formatado__c, consultant);
      }

      Map<String, MessagingEndUser> endUserByKey = MessagingEndUserService.findAvailableByPhone(
        consultantByPhone.keySet(),
        'Consultor__c',
        null
      );

      for (Consultor__c consultant : consultantByPhone.values()) {
        MessagingEndUser endUser = endUserByKey.get(
          consultant.Telefone_Formatado__c
        );

        if (endUser == null) {
          endUser = MessagingEndUserService.buildNewEndUser(
            consultant.Telefone_Formatado__c,
            consultant.Name,
            channelPartnerId
          );
          endUser.Consultor__c = consultant.Id;
        } else {
          endUser.Consultor__c = consultant.Id;
        }
        messagingUsers.add(endUser);
      }

      MessagingEndUserService.save(messagingUsers, true);
    } catch (Exception ex) {
      System.debug('##Erro ao criar messaging user: ' + ex.getMessage());
      System.debug('##Stack: ' + ex.getStackTraceString());
      System.debug('##Line: ' + ex.getLineNumber());
    }
  }
}
