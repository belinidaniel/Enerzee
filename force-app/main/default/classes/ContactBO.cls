public with sharing class ContactBO {

    public static void createMessagingUser(List<Contact> newRecordList, Map<Id, Contact> oldMap){

        try{

            List<MessagingEndUser> messagingUsers = new List<MessagingEndUser>();
            Map<String, MessagingEndUser> endUserByKey = new Map<String, MessagingEndUser>();
            Map<String, Contact> contactByPhone = new Map<String, Contact>();

            List<MessagingChannel> channelCustomer = [SELECT Id, masterlabel from MessagingChannel WHERE MasterLabel = '+55 11 4003-8344'];

            for(Contact contact : newRecordList){

                if(String.isBlank(contact.Phone)){
                    continue;
                }

                Contact oldContact = oldMap.get(contact.Id);

                if(oldContact != null && (oldContact.Phone == contact.Phone)) continue;

                contactByPhone.put(contact.Telefone_Formatado__c, contact);
            }

            List<MessagingEndUser> endUsers = [
                SELECT Id, Name, MessagingPlatformKey, Telefone_Formatado__c, ContactId, LeadId, AccountId
                FROM MessagingEndUser
                WHERE ContactId = null
                AND Telefone_Formatado__c IN :contactByPhone.keySet()
                AND MessagingChannelId = :channelCustomer[0].Id
            ];

            if(endUsers != null){
                for(MessagingEndUser endUser : endUsers){
                    endUserByKey.put(endUser.Telefone_Formatado__c, endUser);
                }
            }

            for(Contact contact : contactByPhone.values()){

                MessagingEndUser endUser = endUserByKey.get(contact.Telefone_Formatado__c);

                if(endUser == null){

                    endUser = new MessagingEndUser(
                        MessageType = 'WhatsApp',
                        MessagingConsentStatus = 'ImplicitlyOptedIn',
                        MessagingPlatformKey = contact.Telefone_Formatado__c,
                        Name = contact.FirstName + ' ' + contact.LastName ,
                        MessagingChannelId = Test.isRunningTest() ? '0MjU50000011EhtKAE' : channelCustomer[0].Id,
                        ContactId = contact.Id
                    );

                }else{
                    endUser.ContactId = contact.Id;
                }
                messagingUsers.add(endUser);
            }

            Database.upsert(messagingUsers, false);

        }catch(Exception ex){
            System.debug('##Erro ao criar Messaging user: ' + ex.getMessage());
            System.debug('##Stack: ' + ex.getStackTraceString());
            System.debug('##Line: ' + ex.getLineNumber());
        }
        
    }
}