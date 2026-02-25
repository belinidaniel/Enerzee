public with sharing class IntegradorBO {
  public static void sendIntegradorToSAP(List<Integradores__c> integradores) {
    Set<Id> integradorIds = new Set<Id>();

    for (Integradores__c integrador : integradores) {
      integradorIds.add(integrador.Id);
    }

    if (!integradorIds.isEmpty()) {
      IntegracaoSAPIntegrador.sendIntegrador(integradorIds);
    }
  }

  public static void createMessagingUser(
    List<Integradores__c> integradores,
    Map<Id, Integradores__c> oldMap
  ) {
    try {
      List<MessagingEndUser> messagingUsers = new List<MessagingEndUser>();
      Map<String, Integradores__c> integByPhone = new Map<String, Integradores__c>();
      Id channelPartnerId = MessagingEndUserService.resolveChannelId(
        '+55 11 4003-8852'
      );

      for (Integradores__c integ : integradores) {
        if (String.isBlank(integ.Telefone__c)) {
          continue;
        }

        Integradores__c oldInteg = oldMap.get(integ.Id);

        if (oldInteg != null && (oldInteg.Telefone__c == integ.Telefone__c))
          continue;

        integByPhone.put(integ.Telefone_Formatado__c, integ);
      }

      Map<String, MessagingEndUser> endUserByKey = MessagingEndUserService.findAvailableByPhone(
        integByPhone.keySet(),
        'Integrador__c',
        null
      );

      for (Integradores__c integ : integByPhone.values()) {
        MessagingEndUser endUser = endUserByKey.get(
          integ.Telefone_Formatado__c
        );

        if (endUser == null) {
          endUser = MessagingEndUserService.buildNewEndUser(
            integ.Telefone_Formatado__c,
            integ.Name,
            channelPartnerId
          );
          endUser.Integrador__c = integ.Id;
        } else {
          endUser.Integrador__c = integ.Id;
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
