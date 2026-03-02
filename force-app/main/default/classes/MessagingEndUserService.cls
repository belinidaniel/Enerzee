/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 02-25-2026
 * @last modified by	 : Daniel Belini
 **/
public with sharing class MessagingEndUserService {
  public static final String TEST_CHANNEL_ID = '0MjU50000011EhtKAE';
  private static final String MESSAGE_TYPE_WHATSAPP = 'WhatsApp';
  private static final String CONSENT_STATUS_IMPLICIT = 'ImplicitlyOptedIn';

  public static Id resolveChannelId(String channelLabel) {
    if (String.isBlank(channelLabel)) {
      return null;
    }

    List<MessagingChannel> channels = [
      SELECT Id
      FROM MessagingChannel
      WHERE MasterLabel = :channelLabel
      LIMIT 1
    ];

    if (!channels.isEmpty()) {
      return channels[0].Id;
    }

    return Test.isRunningTest() ? TEST_CHANNEL_ID : null;
  }

  public static List<Id> resolveChannelIds(Set<String> channelLabels) {
    List<Id> channelIds = new List<Id>();

    if (channelLabels == null || channelLabels.isEmpty()) {
      if (Test.isRunningTest()) {
        channelIds.add(TEST_CHANNEL_ID);
      }
      return channelIds;
    }

    for (MessagingChannel channel : [
      SELECT Id
      FROM MessagingChannel
      WHERE MasterLabel IN :channelLabels
    ]) {
      channelIds.add(channel.Id);
    }

    if (channelIds.isEmpty() && Test.isRunningTest()) {
      channelIds.add(TEST_CHANNEL_ID);
    }

    return channelIds;
  }

  public static Map<String, MessagingEndUser> findAvailableByPhone(
    Set<String> formattedPhones,
    String ownerFieldApi,
    Id channelId
  ) {
    Map<String, MessagingEndUser> endUserByPhone = new Map<String, MessagingEndUser>();
    Map<String, Schema.SObjectField> fieldByApi = Schema.SObjectType.MessagingEndUser.fields.getMap();

    if (formattedPhones == null || formattedPhones.isEmpty()) {
      return endUserByPhone;
    }

    List<String> queryFields = new List<String>{
      'Id',
      'Name',
      'MessagingPlatformKey',
      'MessagingChannelId',
      'Telefone_Formatado__c',
      'AccountId',
      'ContactId',
      'Consultor__c',
      'Integrador__c'
    };

    if (
      String.isNotBlank(ownerFieldApi) &&
      fieldByApi.containsKey(ownerFieldApi) &&
      !queryFields.contains(ownerFieldApi)
    ) {
      queryFields.add(ownerFieldApi);
    }

    String query =
      'SELECT ' +
      String.join(queryFields, ',') +
      ' FROM MessagingEndUser WHERE Telefone_Formatado__c IN :formattedPhones';

    List<MessagingEndUser> endUsers = Database.query(query);

    for (MessagingEndUser endUser : endUsers) {
      if (String.isBlank(endUser.Telefone_Formatado__c)) {
        continue;
      }

      if (channelId != null && endUser.MessagingChannelId != channelId) {
        continue;
      }

      if (
        String.isNotBlank(ownerFieldApi) &&
        fieldByApi.containsKey(ownerFieldApi) &&
        endUser.get(ownerFieldApi) != null
      ) {
        continue;
      }

      if (!endUserByPhone.containsKey(endUser.Telefone_Formatado__c)) {
        endUserByPhone.put(endUser.Telefone_Formatado__c, endUser);
      }
    }

    return endUserByPhone;
  }

  public static MessagingEndUser buildNewEndUser(
    String formattedPhone,
    String displayName,
    Id channelId
  ) {
    return new MessagingEndUser(
      MessageType = MESSAGE_TYPE_WHATSAPP,
      MessagingConsentStatus = CONSENT_STATUS_IMPLICIT,
      MessagingPlatformKey = formattedPhone,
      Name = displayName,
      MessagingChannelId = channelId
    );
  }

  public static void save(
    List<MessagingEndUser> messagingUsers,
    Boolean useUpsert
  ) {
    if (messagingUsers == null || messagingUsers.isEmpty()) {
      return;
    }

    if (useUpsert) {
      Database.upsert(messagingUsers, false);
      return;
    }

    Database.insert(messagingUsers, false);
  }

  public static String composeName(String firstName, String lastName) {
    String normalizedFirstName = firstName == null ? '' : firstName.trim();
    String normalizedLastName = lastName == null ? '' : lastName.trim();

    String fullName = (normalizedFirstName + ' ' + normalizedLastName).trim();

    return String.isBlank(fullName) ? null : fullName;
  }

  public static String normalizePhone(String rawPhone) {
    if (String.isBlank(rawPhone)) {
      return null;
    }

    String phone = rawPhone
      .deleteWhiteSpace()
      .replace('(', '')
      .replace(')', '')
      .replace('.', '')
      .replace('-', '');

    if (phone.length() == 10) {
      phone = '55' + phone;
    }

    if (phone.length() == 11) {
      phone = '55' + phone.substring(0, 2) + phone.substring(3, 11);
    }

    if (phone.startsWith('55') && phone.length() == 13) {
      phone = phone.substring(0, 4) + phone.substring(5, 13);
    }

    return phone;
  }
}
