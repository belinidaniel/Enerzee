@IsTest
public with sharing class ClickSignUtilsTest {
    
    @IsTest
    static void testGetIntegration() {
        // Arrange
        String name = 'CREATE_ENVELOPE';

        // Act
        Integrador__mdt result = ClickSignUtils.getIntegration(name);

        // Assert
    }

    @IsTest
    static void testCreateLogWithException() {
        // Arrange
        String className = 'TestClass';
        String methodName = 'testMethod';
        Exception source = new DmlException('Test exception');

        // Act
        ClickSignLog__c log = ClickSignUtils.createLog(className, methodName, source);

        // Assert
        System.assertNotEquals(null, log);
        System.assertEquals(className, log.Class__c);
        System.assertEquals(methodName, log.Method__c);
        System.assertEquals('Test exception', log.Message__c);
    }

    @IsTest
    static void testCreateLogWithHttpResponse() {
        // Arrange
        String className = 'TestClass';
        String methodName = 'testMethod';
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody('{"message":"success"}');

        // Act
        ClickSignLog__c log = ClickSignUtils.createLog(className, methodName, response);

        // Assert
        System.assertNotEquals(null, log);
        System.assertEquals(className, log.Class__c);
        System.assertEquals(methodName, log.Method__c);
        System.assertEquals(200, log.StatusCode__c);
        System.assertEquals('{"message":"success"}', log.ResponseBody__c);
    }

    @IsTest
    static void testGetOrCreateClickSign() {
        // Arrange
        Account account = new Account(Name = 'Test Account');
        insert account;

        ClickSign__c clickSign = new ClickSign__c(
            RecordId__c = account.Id,
            Status__c = 'Draft'
        );
        insert clickSign;

        // Act
        ClickSign__c result = ClickSignUtils.getOrCreateClickSign(account);

        // Assert
        System.assertNotEquals(null, result);
        System.assertEquals(clickSign.Id, result.Id);
    }


    @IsTest
    static void testCreateClickSign() {
        // Arrange
        Account account = new Account(Name = 'Test Account');
        insert account;

        // Act
        ClickSign__c clickSign = ClickSignUtils.createClickSign(account);

        // Assert
        System.assertNotEquals(null, clickSign);
        System.assertEquals('Documents', clickSign.CurrentStep__c);
        System.assertEquals('Draft', clickSign.Status__c);
        System.assertEquals(account.Id, clickSign.RecordId__c);
    }
}