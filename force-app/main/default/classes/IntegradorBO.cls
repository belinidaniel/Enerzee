public with sharing class IntegradorBO {
    public static void sendIntegradorToSAP(List<Integradores__c> integradores) {
        Set<Id> integradorIds = new Set<Id>();
        
        for(Integradores__c integrador : integradores){
            integradorIds.add(integrador.Id);
        }

        if(!integradorIds.isEmpty()){
            IntegracaoSAPIntegrador.sendIntegrador(integradorIds);
        }
        
    }

    public static void createMessagingUser(List<Integradores__c> integradores, Map<Id, Integradores__c> oldMap){

        try{

            List<MessagingEndUser> messagingUsers = new List<MessagingEndUser>();
            Map<String, MessagingEndUser> endUserByKey = new Map<String, MessagingEndUser>();
            Map<String, Integradores__c> integByPhone = new Map<String, Integradores__c>();

            List<MessagingChannel> channelPartner = [SELECT Id, masterlabel from MessagingChannel WHERE MasterLabel = '+55 11 4003-8852'];

            for(Integradores__c integ : integradores){

                if(String.isBlank(integ.Telefone__c)){
                    continue;
                }

                Integradores__c oldInteg = oldMap.get(integ.Id);

                if(oldInteg != null && (oldInteg.Telefone__c == integ.Telefone__c)) continue;

                integByPhone.put(integ.Telefone_Formatado__c, integ);
            }

            List<MessagingEndUser> endUsers = [
                SELECT Id, Name, MessagingPlatformKey, Telefone_Formatado__c, ContactId, AccountId, Integrador__c
                FROM MessagingEndUser
                WHERE Integrador__c = null
                AND Telefone_Formatado__c IN :integByPhone.keySet()
            ];

            if(endUsers != null){
                for(MessagingEndUser endUser : endUsers){
                    endUserByKey.put(endUser.Telefone_Formatado__c, endUser);
                }
            }

            for(Integradores__c integ : integByPhone.values()){

                MessagingEndUser endUser = endUserByKey.get(integ.Telefone_Formatado__c);

                if(endUser == null){

                    endUser = new MessagingEndUser(
                        MessageType = 'WhatsApp',
                        MessagingConsentStatus = 'ImplicitlyOptedIn',
                        MessagingPlatformKey = integ.Telefone_Formatado__c,
                        Name = integ.Name,
                        MessagingChannelId = Test.isRunningTest() ? '0MjU50000011EhtKAE' : channelPartner[0].Id,
                        Integrador__c = integ.Id
                    );

                }else{
                    endUser.Integrador__c = integ.Id;
                }

                messagingUsers.add(endUser);
            }

            Database.upsert(messagingUsers, false);

        }catch(Exception ex){
            System.debug('##Erro ao criar messaging user: ' + ex.getMessage());
            System.debug('##Stack: ' + ex.getStackTraceString());
            System.debug('##Line: ' + ex.getLineNumber());
        }
        
    }
}