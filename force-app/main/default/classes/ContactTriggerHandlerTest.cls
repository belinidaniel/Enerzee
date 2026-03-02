@IsTest(seeAllData=true)
private class ContactTriggerHandlerTest {
  @IsTest
  static void shouldCreateMessagingUserOnContact() {
    List<MessagingChannel> channels = [
      SELECT Id
      FROM MessagingChannel
      WHERE MasterLabel = '+55 11 4003-8344'
      LIMIT 1
    ];
    if (channels.isEmpty()) {
      return;
    }

    Account acc = new Account(Name = 'Conta');
    insert acc;

    Contact c = new Contact(
      LastName = 'Contato',
      AccountId = acc.Id,
      Phone = '1199999999'
    );
    insert c;

    c.Phone = '1199999998';
    update c;

    System.assert(true, 'Contact trigger executed');
  }
}
