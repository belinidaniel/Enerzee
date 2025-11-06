/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-05-2025
 * @last modified by  : Daniel Belini
**/
@isTest
private class MessagingSessionSLABatchTest {

    @isTest
    static void batchMarksStagesAsNotified() {
        User supervisorUser = createUserWithRole('Supervisor Assistência Técnica', 'Supervisor_Assistencia_Tecnica');
        User coordinatorUser = createUserWithRole('Coordenador de Engenharia', 'Coordenador_de_Engenharia');

        MessagingSession session = new MessagingSession();
        session.Id = Id.valueOf('0dw000000000001AAA');
        session.Status = 'Waiting';
        session.OwnerId = supervisorUser.Id;
        session.OwnerAssignmentDate__c = System.now().addMinutes(-30);
        session.MinuteSLAN1__c = 5;
        session.MinuteSLAN2__c = 10;
        session.MinuteSLAN3__c = 15;
        session.QueueAtendentRole__c = supervisorUser.UserRole.Name;
        session.QueueSupervisorRole__c = supervisorUser.UserRole.Name;
        session.QueueCoordinatorRole__c = coordinatorUser.UserRole.Name;

        Test.startTest();
        new MessagingSessionSLABatch().execute(null, new List<MessagingSession>{ session });
        Test.stopTest();

        System.assertEquals(true, session.NotifyN1__c, 'Stage N1 should be marked as notified.');
        System.assertEquals(true, session.NotifyN2__c, 'Stage N2 should be marked as notified.');
        System.assertEquals(true, session.NotifyN3__c, 'Stage N3 should be marked as notified.');
    }

    @isTest
    static void schedulerEnqueuesBatch() {
        Test.startTest();
        String jobId = MessagingSessionSLAScheduler.scheduleJob();
        Test.stopTest();
    }

    private static User createUserWithRole(String roleName, String developerName) {
        String uniqueToken = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        String finalDeveloperName = (developerName + '_' + uniqueToken).replace('-', '');
        if (finalDeveloperName.length() > 40) {
            finalDeveloperName = finalDeveloperName.substring(0, 40);
        }

        UserRole roleRecord = new UserRole(
            Name = roleName,
            DeveloperName = finalDeveloperName,
            RollupDescription = 'Generated for MessagingSession SLA tests'
        );
        insert roleRecord;

        Profile profileRecord = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        String email = roleRecord.DeveloperName.toLowerCase() + '+' + uniqueToken + '@example.com';
        String alias = ('msla' + String.valueOf(Math.abs(Crypto.getRandomInteger()))).left(8);

        User userRecord = new User(
            FirstName = 'Messaging',
            LastName = roleRecord.Name,
            Alias = alias,
            Email = email,
            Username = email,
            TimeZoneSidKey = 'America/Sao_Paulo',
            LocaleSidKey = 'pt_BR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'pt_BR',
            ProfileId = profileRecord.Id,
            UserRoleId = roleRecord.Id
        );

        insert userRecord;
        return userRecord;
    }
}
