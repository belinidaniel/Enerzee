global class OmniChannelLoginHelper {
    @InvocableMethod
    public static void setUserPresence(List<Id> userIds) {
        List<ServicePresenceStatus> availableStatuses = [
            SELECT Id 
            FROM ServicePresenceStatus 
            WHERE DeveloperName like '%Online%'
        ];

        if (availableStatuses != null) {
            List<UserServicePresence> userPresences = new List<UserServicePresence>();
            
            for (Id userId : userIds) {
                UserServicePresence usp = new UserServicePresence();
                usp.UserId = userId;
                usp.ServicePresenceStatusId = availableStatuses[0].Id;
                userPresences.add(usp);
            }
            
            if (!userPresences.isEmpty()) {
                upsert userPresences;
            }
        }
    }
}