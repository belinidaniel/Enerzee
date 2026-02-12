@IsTest
private class CaseBOTest {
    @IsTest
    static void shouldCreateAttachmentsAndContacts() {
        Case c = new Case(Subject = 'Teste', Status = 'New', Origin = 'Web To Case Integrador');
        c.CertidaoNegativaTrabalhista__c = 'data:application/pdf;base64,' + TestMetadataUtils.base64('arquivo');
        c.EmailIntegradorWeb__c = 'integrador@teste.com';
        c.NomeIntegradorWeb__c = 'Integrador Teste';
        c.SuppliedPhone = '1199999999';
        insert c;

        CaseBO.CreateAttachments(new List<Case>{ c });
        System.assert([SELECT count() FROM Attachment WHERE ParentId = :c.Id] > 0);

        CaseBO.AssignContactForCase(new List<Case>{ c });
        System.assertNotEquals(null, c.ContactId);
    }
}
