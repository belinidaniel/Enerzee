public class AccountBO {
  // Atribuir consultor ao campo correspondente na Conta (Cliente), ao receber ID externo do consultor via integração
  public static void assignSellerToIntegratedClient(List<Account> newRecords) {
    Set<String> externalSellerIds = new Set<String>();
    Map<String, Id> externalSellerIdToSellerId = new Map<String, Id>();

    for (Account client : newRecords) {
      if (client.IdExternoConsultor__c != null) {
        externalSellerIds.add(client.IdExternoConsultor__c);
      }
    }

    if (!externalSellerIds.isEmpty()) {
      for (Consultor__c seller : [
        SELECT Id, IdVirtualOffice__c
        FROM Consultor__c
        WHERE IdVirtualOffice__c IN :externalSellerIds
      ]) {
        externalSellerIdToSellerId.put(seller.IdVirtualOffice__c, seller.Id);
      }

      for (Account client : newRecords) {
        client.Consultor__c = externalSellerIdToSellerId.get(
          client.IdExternoConsultor__c
        );
      }
    }
  }

  public static void assignCPFCNPJToIdentificationNumber(
    List<Account> newRecordList
  ) {
    for (Account account : newRecordList) {
      if (account.NumeroIdentificacao__c == null) {
        account.NumeroIdentificacao__c = account.SeCPFouCNPJ__c;
      }
    }
  }

  public static void sendCustomerRecordToSAP(List<Account> newRecordList) {
    User runningUser = [
      SELECT Id, Name, Profile.Name
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];

    if (!runningUser.Name.equalsIgnoreCase('Integrador SAP')) {
      Set<Id> accountIds = new Set<Id>();
      for (Account account : newRecordList) {
        accountIds.add(account.Id);
      }

      IntegracaoSAPCliente.sendCliente(accountIds);
    }
  }

  public static void createMessagingUser(
    List<Account> newRecordList,
    Map<Id, Account> oldMap
  ) {
    try {
      List<MessagingEndUser> messagingUsers = new List<MessagingEndUser>();
      Map<String, Account> accountByPhone = new Map<String, Account>();
      Id channelCustomerId = MessagingEndUserService.resolveChannelId(
        '+55 11 4003-8344'
      );

      for (Account account : newRecordList) {
        if (String.isBlank(account.Phone)) {
          continue;
        }

        Account oldAccount = oldMap.get(account.Id);

        if (oldAccount != null && (oldAccount.Phone == account.Phone))
          continue;

        accountByPhone.put(account.Telefone_Formatado__c, account);
      }

      Map<String, MessagingEndUser> endUserByKey = MessagingEndUserService.findAvailableByPhone(
        accountByPhone.keySet(),
        'AccountId',
        null
      );

      for (Account account : accountByPhone.values()) {
        MessagingEndUser endUser = endUserByKey.get(
          account.Telefone_Formatado__c
        );

        if (endUser == null) {
          endUser = MessagingEndUserService.buildNewEndUser(
            account.Telefone_Formatado__c,
            account.Name,
            channelCustomerId
          );
          endUser.AccountId = account.Id;
        } else {
          endUser.AccountId = account.Id;
        }
        messagingUsers.add(endUser);
      }

      MessagingEndUserService.save(messagingUsers, true);
    } catch (Exception ex) {
      System.debug('##Erro ao criar Messaging user: ' + ex.getMessage());
      System.debug('##Stack: ' + ex.getStackTraceString());
      System.debug('##Line: ' + ex.getLineNumber());
    }
  }
}
