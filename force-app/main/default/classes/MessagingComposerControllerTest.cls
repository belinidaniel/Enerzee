@IsTest
private class MessagingComposerControllerTest {

    @IsTest
    static void testSearchRecipients() {
        Account acc = new Account(Name = 'Conta Teste', Phone = '11999990000');
        insert acc;

        Contact con = new Contact(LastName = 'Cliente Teste', AccountId = acc.Id, Phone = '11988880000');
        insert con;

        Test.startTest();
        List<MessagingComposerController.RecipientDTO> results = MessagingComposerController.searchRecipients('Teste');
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Deve retornar ao menos um resultado da busca.');
    }

    @IsTest
    static void testGetMessageDefinitions() {
        Test.startTest();
        List<MessagingComposerController.MessageTemplateDTO> defs = MessagingComposerController.getMessageDefinitions(null);
        Test.stopTest();

        System.assert(!defs.isEmpty(), 'Stub de templates precisa retornar valores em teste.');
        System.assertEquals('Template_De_Teste', defs[0].fullName);
    }

    @IsTest
    static void testSendMessageInTestMode() {
        MessagingComposerController.SendMessageRequest req = new MessagingComposerController.SendMessageRequest();
        req.messageDefinitionName = 'Template_De_Teste';
        req.messagingChannelId = '0Mj000000000000AAA';
        req.messagingEndUserId = '0Mj000000000001AAA';

        Test.startTest();
        MessagingComposerController.SendMessageResponse resp = MessagingComposerController.sendMessage(req);
        Test.stopTest();

        System.assertEquals('Simulado', resp.status);
        System.assertEquals(req.messagingEndUserId, resp.messagingEndUserId);
    }
}
