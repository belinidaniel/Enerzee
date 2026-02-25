public with sharing class ContactBO {
  public static void createMessagingUser(
    List<Contact> newRecordList,
    Map<Id, Contact> oldMap
  ) {
    try {
      List<MessagingEndUser> messagingUsers = new List<MessagingEndUser>();
      Map<String, Contact> contactByPhone = new Map<String, Contact>();
      Id channelCustomerId = MessagingEndUserService.resolveChannelId(
        '+55 11 4003-8344'
      );

      for (Contact contact : newRecordList) {
        if (String.isBlank(contact.Phone)) {
          continue;
        }

        Contact oldContact = oldMap.get(contact.Id);

        if (oldContact != null && (oldContact.Phone == contact.Phone))
          continue;

        contactByPhone.put(contact.Telefone_Formatado__c, contact);
      }

      Map<String, MessagingEndUser> endUserByKey = MessagingEndUserService.findAvailableByPhone(
        contactByPhone.keySet(),
        'ContactId',
        channelCustomerId
      );

      for (Contact contact : contactByPhone.values()) {
        MessagingEndUser endUser = endUserByKey.get(
          contact.Telefone_Formatado__c
        );

        if (endUser == null) {
          endUser = MessagingEndUserService.buildNewEndUser(
            contact.Telefone_Formatado__c,
            MessagingEndUserService.composeName(
              contact.FirstName,
              contact.LastName
            ),
            channelCustomerId
          );
          endUser.ContactId = contact.Id;
        } else {
          endUser.ContactId = contact.Id;
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
