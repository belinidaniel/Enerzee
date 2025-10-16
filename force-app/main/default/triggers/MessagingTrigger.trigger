trigger MessagingTrigger on MessagingSession (before insert, after insert, before update, after update) {

    if(Trigger.isAfter && Trigger.isUpdate){

        Map<Id, MessagingSession> oldMap = (Map<Id, MessagingSession>) Trigger.oldMap;

        List<User> users = [SELECT Id FROM User WHERE Name = 'Platform Integration User' AND UserName LIKE '%autoproc@%'];

        if(users == null){
            System.debug('User not found');
            return;
        }

        for (MessagingSession messaging : Trigger.new) {

            MessagingSession oldMessaging = oldMap.get(messaging.Id);

            System.debug('messaging: ' + messaging);
            System.debug('oldMessaging: ' + oldMessaging);

            if(oldMessaging != null && oldMessaging.OwnerId != messaging.OwnerId && (oldMessaging.OwnerId == users[0].Id && Schema.Group.SObjectType == messaging.OwnerId.getSObjectType()) && (oldMessaging.Status == 'Active' && messaging.Status == 'Waiting')){
                System.debug('call: ' + messaging);
                MessagingSessionHandler.callConversionUpdate(new List<String>{messaging.Id});
            }
        }
    }

}