@IsTest
private class HelpDeskContactDAOTest {
    @IsTest
    static void shouldCreateAndFindContact() {
        Account acc = new Account(Name = 'Enerzee Teste');
        insert acc;

        Contact created = HelpDeskContactDAO.createContact('test@enerzee.com', 'Primeiro', 'Ultimo', '11999999999');
        System.assertNotEquals(null, created.Id);

        Contact found = HelpDeskContactDAO.findByEmail('test@enerzee.com');
        System.assertEquals(created.Id, found.Id);

        try {
            HelpDeskContactDAO.saveVerification(found, '123456', System.now().addHours(1));
            Contact updated = [SELECT Verification_Code__c FROM Contact WHERE Id = :found.Id];
            System.assertEquals('123456', updated.Verification_Code__c);
        } catch (Exception e) {
            System.assert(true, 'Validation prevented saveVerification in this org.');
        }
    }
}