/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ClickSignDAOTest {
  @IsTest
  static void shouldHandleClickSignRecords() {
    Account acc = new Account(Name = 'Conta');
    insert acc;

    ClickSign__c cs = ClickSignDAO.getOrCreateClickSign(acc.Id);
    System.assertNotEquals(null, cs.Id);

    ClickSign__c fetched = ClickSignDAO.getClickSignById(cs.Id);
    System.assertEquals(cs.Id, fetched.Id);

    ClickSignTemplate__c template = new ClickSignTemplate__c(
      Name = 'Template',
      SourceObject__c = 'Account',
      IsActivate__c = true,
      ButtonLabel__c = 'Assinar'
    );
    insert template;

    ClickSignSigner__c signer = new ClickSignSigner__c(
      Name = 'Signer',
      SignerType__c = 'Any',
      ClickSignTemplate__c = template.Id
    );
    insert signer;

    ClickSignDAO.saveTemplateId(cs.Id, template.Id);
    ClickSign__c updated = [
      SELECT ClickSignTemplate__c
      FROM ClickSign__c
      WHERE Id = :cs.Id
    ];
    System.assertEquals(template.Id, updated.ClickSignTemplate__c);

    List<ClickSignTemplate__c> activeTemplates = ClickSignDAO.getActiveTemplates();
    System.assert(activeTemplates.size() > 0);

    List<ClickSignTemplate__c> templatesByRecord = ClickSignDAO.getTemplatesByRecordId(
      acc.Id
    );
    System.assert(templatesByRecord.size() > 0);

    List<ClickSignTemplate__c> templatesById = ClickSignDAO.getTemplatesById(
      template.Id
    );
    System.assertEquals(1, templatesById.size());

    ClickSign__c draft = new ClickSign__c(
      RecordId__c = acc.Id,
      Status__c = 'Draft'
    );
    insert draft;
    ClickSign__c recreated = ClickSignDAO.cancelAndCreateClickSign(acc.Id);
    System.assertNotEquals(null, recreated.Id);
  }

  @IsTest
  static void shouldUpdateDeleteAndListRecords() {
    Account acc = new Account(Name = 'Conta DAO');
    insert acc;

    ClickSign__c clickSign = ClickSignDAO.getOrCreateClickSign(acc.Id);
    clickSign.CurrentStep__c = 'Recipients';

    ClickSignDAO.updateClickSign(clickSign);

    ClickSign__c stored = [
      SELECT CurrentStep__c, Status__c
      FROM ClickSign__c
      WHERE Id = :clickSign.Id
    ];
    System.assertEquals('Recipients', stored.CurrentStep__c);
    System.assertEquals('Draft', stored.Status__c);

    List<ClickSign__c> records = ClickSignDAO.getClickSignRecords(acc.Id);
    System.assertEquals(1, records.size());
    System.assertEquals(clickSign.Id, records[0].Id);

    ClickSignDAO.deleteClickSign(clickSign);

    ClickSign__c deletedRecord = [
      SELECT IsDeleted
      FROM ClickSign__c
      WHERE Id = :clickSign.Id
      ALL ROWS
    ];
    System.assertEquals(true, deletedRecord.IsDeleted);
  }
}
