@IsTest
private class MessagingEndUserServiceTest {
  @IsTest
  static void shouldNormalizeBrazilPhones() {
    System.assertEquals(
      '551187654321',
      MessagingEndUserService.normalizePhone('(11) 98765-4321')
    );
    System.assertEquals(
      '551133334444',
      MessagingEndUserService.normalizePhone('11 3333-4444')
    );
    System.assertEquals(
      '551187654321',
      MessagingEndUserService.normalizePhone('55 11 98765-4321')
    );
    System.assertEquals(null, MessagingEndUserService.normalizePhone(null));
  }

  @IsTest
  static void shouldComposeNameSafely() {
    System.assertEquals(
      'Daniel Belini',
      MessagingEndUserService.composeName(' Daniel ', ' Belini ')
    );
    System.assertEquals(
      'Belini',
      MessagingEndUserService.composeName(null, 'Belini')
    );
    System.assertEquals(null, MessagingEndUserService.composeName(null, null));
  }

  @IsTest
  static void shouldFallbackToTestChannelWhenNoMetadataIsPresent() {
    Id channelId = MessagingEndUserService.resolveChannelId(
      'Canal Inexistente Teste'
    );
    System.assertEquals(MessagingEndUserService.TEST_CHANNEL_ID, channelId);

    List<Id> channelIds = MessagingEndUserService.resolveChannelIds(
      new Set<String>{ 'Canal Inexistente Teste' }
    );
    System.assertEquals(1, channelIds.size());
    System.assertEquals(MessagingEndUserService.TEST_CHANNEL_ID, channelIds[0]);
  }

  @IsTest
  static void shouldHandleLookupAndSaveHelpers() {
    Set<String> phones = new Set<String>{ '5511999999999' };
    Map<String, MessagingEndUser> usersByPhone = MessagingEndUserService.findAvailableByPhone(
      phones,
      'OwnerId',
      null
    );
    System.assertEquals(0, usersByPhone.size());

    MessagingEndUser endUser = MessagingEndUserService.buildNewEndUser(
      '5511999999999',
      'Contato Teste',
      MessagingEndUserService.TEST_CHANNEL_ID
    );

    MessagingEndUserService.save(new List<MessagingEndUser>{ endUser }, true);
    MessagingEndUserService.save(new List<MessagingEndUser>{ endUser }, false);
  }
}
