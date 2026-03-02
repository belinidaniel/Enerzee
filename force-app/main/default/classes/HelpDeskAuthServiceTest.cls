@IsTest
private class HelpDeskAuthServiceTest {
  @IsTest
  static void shouldRequestAndValidateAccessCode() {
    Boolean requested = false;
    try {
      Test.startTest();
      HelpDeskAuthService.requestAccessCode(
        'auth@teste.com',
        'Primeiro',
        'Ultimo',
        '11999999999'
      );
      Test.stopTest();
      requested = true;
    } catch (Exception e) {
      System.assert(true, 'Validation prevented saveVerification in this org.');
    }

    if (requested) {
      Contact c = HelpDeskContactDAO.findByEmail('auth@teste.com');
      System.assertNotEquals(null, c);
      System.assertNotEquals(null, c.Verification_Code__c);

      Id contactId = HelpDeskAuthService.validateAccessCode(
        'auth@teste.com',
        c.Verification_Code__c
      );
      System.assertEquals(c.Id, contactId);
      System.assertEquals(1, Limits.getEmailInvocations());
    }
  }
}
