/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class MessagingComposerControllerCoverageTest {
  private class MetadataNamedCredentialMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);

      if (request.getEndpoint().contains('/tooling/query')) {
        response.setHeader('Content-Type', 'application/json');
        response.setBody(
          '{"records":[{"FullName":"SALES - Oferta","DeveloperName":"Oferta","NamespacePrefix":null,"LastModifiedDate":"2026-03-15T10:00:00.000Z","CreatedBy":{"Name":"Tester"}}]}'
        );
        return response;
      }

      response.setHeader('Content-Type', 'text/xml');
      response.setBody(
        '<?xml version="1.0" encoding="UTF-8"?><Envelope><Body><result><fullName>AFTER - Template XML</fullName><fileName>conversationMessageDefinitions/AfterTemplate.conversationMessageDefinition</fileName><createdByName>Tester</createdByName></result></Body></Envelope>'
      );
      return response;
    }
  }

  @IsTest
  static void testRecipientResolutionByRecordType() {
    Account accountRecord = new Account(
      Name = 'Conta Cobertura',
      Phone = '(11) 4003-8852'
    );
    insert accountRecord;

    Contact contactRecord = new Contact(
      LastName = 'Contato Cobertura',
      AccountId = accountRecord.Id,
      MobilePhone = '(11) 98888-7777'
    );
    insert contactRecord;

    Lead leadRecord = new Lead(
      LastName = 'Lead Cobertura',
      Company = 'Enerzee',
      Phone = '(11) 3666-5555'
    );
    insert leadRecord;

    MessagingComposerController.PreselectRecipientResponse emptyResponse = MessagingComposerController.getRecipientFromRecordId(
      null
    );
    MessagingComposerController.PreselectRecipientResponse contactResponse = MessagingComposerController.getRecipientFromRecordId(
      contactRecord.Id
    );
    MessagingComposerController.PreselectRecipientResponse accountResponse = MessagingComposerController.getRecipientFromRecordId(
      accountRecord.Id
    );
    MessagingComposerController.PreselectRecipientResponse leadResponse = MessagingComposerController.getRecipientFromRecordId(
      leadRecord.Id
    );

    System.assertEquals(null, emptyResponse.recipient);
    System.assertEquals('Contact', contactResponse.recipient.type);
    System.assertEquals(accountRecord.Name, contactResponse.recipient.detail);
    System.assertEquals('Account', accountResponse.recipient.type);
    System.assertEquals('Conta', accountResponse.recipient.detail);
    System.assertEquals('Lead', leadResponse.recipient.type);
    System.assertEquals('Enerzee', leadResponse.recipient.detail);
    System.assertEquals(
      null,
      MessagingComposerController.getMessagingSessionContext(null)
    );
    System.assertEquals(
      null,
      MessagingComposerController.getMessagingSessionContext(accountRecord.Id)
    );
  }

  @IsTest
  static void testTemplateFiltersAndUtilityMethods() {
    List<MessagingComposerController.MessageTemplateDTO> unknownChannel = MessagingComposerController.getMessageDefinitionsByChannelKey(
      'OUTRO'
    );
    List<MessagingComposerController.MessageTemplateDTO> salesChannel = MessagingComposerController.getMessageDefinitionsByChannelKey(
      'SALES'
    );
    List<MessagingComposerController.MessageTemplateDTO> blankChannel = MessagingComposerController.getMessageDefinitionsByChannelKey(
      null
    );

    System.assertEquals(1, unknownChannel.size());
    System.assertEquals('Template_De_Teste', unknownChannel[0].label);
    System.assertEquals(0, salesChannel.size());
    System.assertEquals(0, blankChannel.size());

    System.assertEquals(
      'Teste',
      MessagingComposerController.normalizeSearchTerm('  Teste  ')
    );
    System.assertEquals(
      '11988887777',
      MessagingComposerController.normalizePhone('(11) 98888-7777')
    );
    System.assertEquals(
      null,
      MessagingComposerController.normalizePhone('abc')
    );
    System.assertEquals(
      'Oferta',
      MessagingComposerController.stripPrefix('SALES - Oferta', 'SALES - ')
    );
    System.assertEquals(
      'Template',
      MessagingComposerController.stripPrefix('Template', null)
    );
    System.assertEquals(
      1,
      MessagingComposerController.fetchMessageDefinitions().size()
    );

    Dom.Document doc = new Dom.Document();
    doc.load(
      '<root><result><fullName>SALES - Oferta</fullName><fileName>conversationMessageDefinitions/Oferta.conversationMessageDefinition</fileName><createdByName>Tester</createdByName></result></root>'
    );

    List<MetadataService.FileProperties> properties = new List<MetadataService.FileProperties>();
    MessagingComposerController.collectFileProperties(
      doc.getRootElement(),
      properties
    );

    System.assertEquals(1, properties.size());
    System.assertEquals('SALES - Oferta', properties[0].fullName);
    System.assertEquals(
      true,
      MessagingComposerController.resolveAllowedChannelIds().isEmpty()
    );
  }

  @IsTest
  static void testSearchRecipientsAndNamedCredentialHelpers() {
    Account accountRecord = new Account(
      Name = 'Busca Cobertura',
      Phone = '(11) 4111-0000'
    );
    insert accountRecord;

    Contact contactRecord = new Contact(
      LastName = 'Busca Cobertura',
      AccountId = accountRecord.Id,
      Phone = '(11) 92222-0000'
    );
    insert contactRecord;

    Lead leadRecord = new Lead(
      LastName = 'Busca Cobertura',
      Company = 'Enerzee',
      Phone = '(11) 93333-0000'
    );
    insert leadRecord;

    List<MessagingComposerController.RecipientDTO> results = MessagingComposerController.searchRecipients(
      'Busca Cobertura'
    );
    Set<String> recipientTypes = new Set<String>();
    for (MessagingComposerController.RecipientDTO item : results) {
      recipientTypes.add(item.type);
    }

    System.assert(recipientTypes.contains('Account'));
    System.assert(recipientTypes.contains('Contact'));
    System.assert(recipientTypes.contains('Lead'));

    Test.setMock(HttpCalloutMock.class, new MetadataNamedCredentialMock());
    Test.startTest();
    List<MetadataService.FileProperties> restTemplates = MessagingComposerController.fetchMessageDefinitionsViaNamedCredentialRest();
    List<MetadataService.FileProperties> soapTemplates = MessagingComposerController.fetchMessageDefinitionsViaNamedCredential();
    MetadataService.MetadataPort port = MessagingComposerController.createMetadataPort();
    Test.stopTest();

    System.assertEquals(1, restTemplates.size());
    System.assertEquals('SALES - Oferta', restTemplates[0].fullName);
    System.assertEquals(1, soapTemplates.size());
    System.assertEquals('AFTER - Template XML', soapTemplates[0].fullName);
    System.assertNotEquals(null, port);
  }

  @IsTest
  static void testMessagingBranchesWhenMessagingDataIsAvailable() {
    List<MessagingChannel> channels = [
      SELECT Id, DeveloperName, MasterLabel
      FROM MessagingChannel
      LIMIT 1
    ];
    if (channels.isEmpty()) {
      System.assert(
        true,
        'Nenhum canal de messaging disponivel no org de teste.'
      );
      return;
    }

    MessagingChannel channel = channels[0];
    Account accountRecord = new Account(
      Name = 'Conta Messaging Branch',
      Phone = '(11) 4555-0000'
    );
    insert accountRecord;

    Contact contactRecord = new Contact(
      LastName = 'Contato Messaging Branch',
      AccountId = accountRecord.Id,
      Phone = '(11) 96666-0000'
    );
    insert contactRecord;

    try {
      MessagingEndUser endUser = new MessagingEndUser(
        ContactId = contactRecord.Id,
        AccountId = accountRecord.Id,
        MessagingPlatformKey = '11966660000',
        Name = 'Messaging Branch User',
        MessageType = 'WhatsApp',
        MessagingChannelId = channel.Id
      );
      insert endUser;

      MessagingSession session = new MessagingSession(
        MessagingEndUserId = endUser.Id,
        MessagingChannelId = channel.Id,
        Status = 'New',
        ConversationId = '0dwU50000034lLBIAY'
      );
      insert session;

      MessagingComposerController.SessionContext context = MessagingComposerController.getMessagingSessionContext(
        session.Id
      );
      MessagingComposerController.PreselectRecipientResponse sessionResponse = MessagingComposerController.getRecipientFromRecordId(
        session.Id
      );
      MessagingComposerController.PreselectRecipientResponse endUserResponse = MessagingComposerController.getRecipientFromRecordId(
        endUser.Id
      );

      System.assertEquals(endUser.Id, context.messagingEndUserId);
      System.assertEquals(channel.Id, context.messagingChannelId);
      System.assertEquals(endUser.Id, sessionResponse.recipient.id);
      System.assertEquals('MessagingEndUser', sessionResponse.recipient.type);
      System.assertEquals(
        endUser.Id,
        endUserResponse.recipient.messagingEndUserId
      );

      System.assertEquals(
        channel.Id,
        MessagingComposerController.resolveChannelId(
          null,
          null,
          channel.DeveloperName,
          null
        )
      );
      System.assertEquals(
        endUser.Id,
        MessagingComposerController.findExistingEndUser(
          contactRecord.Id,
          accountRecord.Id,
          channel.Id
        )
      );
      System.assertEquals(
        endUser.Id,
        MessagingComposerController.findExistingEndUserByPhone(
          '11966660000',
          channel.Id
        )
      );
      System.assertEquals(
        session.Id,
        MessagingComposerController.findLatestSession(endUser.Id, channel.Id).Id
      );

      MessagingComposerController.SendMessageRequest requestByPhone = new MessagingComposerController.SendMessageRequest();
      requestByPhone.messagingChannelId = channel.Id;
      requestByPhone.phone = '(11) 96666-0000';
      System.assertEquals(
        endUser.Id,
        MessagingComposerController.resolveMessagingEndUser(requestByPhone)
      );

      MessagingComposerController.SendMessageRequest requestByContact = new MessagingComposerController.SendMessageRequest();
      requestByContact.messagingChannelId = channel.Id;
      requestByContact.contactId = contactRecord.Id;
      System.assertEquals(
        endUser.Id,
        MessagingComposerController.resolveMessagingEndUser(requestByContact)
      );

      String recipientJson =
        '{"id":"' +
        endUser.Id +
        '","type":"MessagingEndUser","name":"Messaging Branch User","phone":"(11) 96666-0000","messagingEndUserId":"' +
        endUser.Id +
        '","messagingChannelId":"' +
        channel.Id +
        '"}';
      Boolean missingFlowRaised = false;
      try {
        MessagingComposerController.prepareSessionAndLaunchFlow(
          recipientJson,
          'CANAL_INEXISTENTE',
          null,
          'Template'
        );
      } catch (Exception ex) {
        missingFlowRaised = true;
      }
      System.assertEquals(true, missingFlowRaised);
    } catch (Exception ex) {
      if (
        ex.getMessage() == null ||
        !ex.getMessage().contains('MessagingDisabled')
      ) {
        throw ex;
      }
    }
  }

  @IsTest
  static void testPureBuilderHelpers() {
    Id fakeChannelId = buildFakeId(
      MessagingChannel.SObjectType,
      '000000000001'
    );
    Id fakeEndUserId = buildFakeId(
      MessagingEndUser.SObjectType,
      '000000000001'
    );

    MessagingChannel channel = new MessagingChannel(
      Id = fakeChannelId,
      DeveloperName = 'SALES',
      MasterLabel = '+55 11 4003-8852'
    );

    MessagingEndUser endUser = new MessagingEndUser(
      Id = fakeEndUserId,
      Name = 'Builder User',
      MessagingPlatformKey = '11911112222',
      MessagingChannelId = fakeChannelId
    );
    endUser.putSObject('MessagingChannel', channel);

    MessagingSession session = new MessagingSession(
      MessagingEndUserId = fakeEndUserId,
      MessagingChannelId = fakeChannelId
    );
    session.put('Telefone__c', '11 4003 8852');
    session.putSObject('MessagingEndUser', endUser);
    session.putSObject('MessagingChannel', channel);

    MessagingComposerController.SessionContext context = MessagingComposerController.buildSessionContext(
      session
    );
    MessagingComposerController.RecipientDTO sessionRecipient = MessagingComposerController.buildSessionRecipient(
      session
    );
    MessagingComposerController.RecipientDTO endUserRecipient = MessagingComposerController.buildEndUserRecipient(
      endUser
    );

    System.assertEquals(fakeEndUserId, context.messagingEndUserId);
    System.assertEquals('Builder User', context.endUserName);
    System.assertEquals('MessagingEndUser', sessionRecipient.type);
    System.assertEquals('11911112222', sessionRecipient.phone);
    System.assertEquals('MessagingEndUser', endUserRecipient.type);
    System.assertEquals(
      'SALES',
      endUserRecipient.messagingChannelDeveloperName
    );

    MessagingComposerController.RecipientDTO recipient = new MessagingComposerController.RecipientDTO();
    recipient.id = fakeEndUserId;
    recipient.type = 'MessagingEndUser';
    recipient.recordTypeDeveloperName = 'PessoaFisica';

    MessagingComposerController.SessionLaunchResponse response = MessagingComposerController.initializeSessionLaunchResponse(
      recipient,
      fakeChannelId,
      fakeEndUserId
    );
    Map<String, Object> flowInputs = MessagingComposerController.buildPrepareSessionFlowInputs(
      recipient,
      fakeChannelId,
      fakeEndUserId,
      '0dw000000000001AAA',
      'SALES',
      '+55 11 4003-8852',
      'Template'
    );

    System.assertEquals(fakeEndUserId, response.messagingEndUserId);
    System.assertEquals(
      'PessoaFisica',
      response.messagingEndUserRecordTypeDeveloperName
    );
    System.assertEquals(
      'Template',
      (String) flowInputs.get('selectedMessageComponentName')
    );
    System.assertEquals(
      'MessagingEndUser',
      (String) flowInputs.get('recipientType')
    );

    MessagingComposerController.SendMessageRequest request = new MessagingComposerController.SendMessageRequest();
    request.messageDefinitionName = 'Template';
    request.messagingChannelId = fakeChannelId;
    Map<String, Object> params = MessagingComposerController.buildSendMessageFlowParams(
      request,
      fakeEndUserId
    );

    System.assertEquals(
      'Template',
      (String) params.get('messageDefinitionName')
    );
    System.assertEquals('Any', (String) params.get('allowedSessionStatus'));
    System.assertEquals(
      'SendNotificationMessages',
      (String) params.get('requestType')
    );
    System.assertEquals(
      'MessagingEndUser',
      (String) params.get('channelConsentType')
    );

    MessagingComposerController.SendMessageResponse queuedResponse = MessagingComposerController.buildSendMessageCompletionResponse(
      fakeEndUserId,
      null,
      'Template'
    );
    MessagingComposerController.SendMessageResponse sentResponse = MessagingComposerController.buildSendMessageCompletionResponse(
      fakeEndUserId,
      session,
      'Template'
    );

    System.assertEquals('Processando', queuedResponse.status);
    System.assertEquals('Enviado', sentResponse.status);
  }

  private static Id buildFakeId(SObjectType sObjectType, String suffix) {
    String prefix = sObjectType.getDescribe().getKeyPrefix();
    return Id.valueOf(prefix + suffix);
  }

  @IsTest
  static void testPrepareAndSendValidationPaths() {
    Boolean missingRecipientRaised = false;
    try {
      MessagingComposerController.prepareSessionAndLaunchFlow(
        null,
        'SALES',
        null,
        'Template'
      );
    } catch (Exception ex) {
      missingRecipientRaised = true;
    }
    System.assertEquals(true, missingRecipientRaised);

    Boolean invalidRecipientRaised = false;
    try {
      MessagingComposerController.prepareSessionAndLaunchFlow(
        '{',
        'SALES',
        null,
        'Template'
      );
    } catch (Exception ex) {
      invalidRecipientRaised = true;
    }
    System.assertEquals(true, invalidRecipientRaised);

    String recipientJson = '{"id":"001000000000001AAA","type":"Account","name":"Conta"}';
    Boolean missingMessageRaised = false;
    try {
      MessagingComposerController.prepareSessionAndLaunchFlow(
        recipientJson,
        'SALES',
        null,
        null
      );
    } catch (Exception ex) {
      missingMessageRaised = true;
    }
    System.assertEquals(true, missingMessageRaised);

    Boolean nullRequestRaised = false;
    try {
      MessagingComposerController.sendMessage(null);
    } catch (Exception ex) {
      nullRequestRaised = true;
    }
    System.assertEquals(true, nullRequestRaised);

    Boolean blankPayloadRaised = false;
    try {
      MessagingComposerController.sendMessageJson(null);
    } catch (Exception ex) {
      blankPayloadRaised = true;
    }
    System.assertEquals(true, blankPayloadRaised);

    Boolean invalidPayloadRaised = false;
    try {
      MessagingComposerController.sendMessageJson('{');
    } catch (Exception ex) {
      invalidPayloadRaised = true;
    }
    System.assertEquals(true, invalidPayloadRaised);

    Boolean missingTemplateRaised = false;
    try {
      MessagingComposerController.sendMessageJson(
        '{"messagingChannelId":"0Mh000000000001AAA"}'
      );
    } catch (Exception ex) {
      missingTemplateRaised = true;
    }
    System.assertEquals(true, missingTemplateRaised);

    Boolean missingChannelRaised = false;
    try {
      MessagingComposerController.sendMessageJson(
        '{"messageDefinitionName":"Template"}'
      );
    } catch (Exception ex) {
      missingChannelRaised = true;
    }
    System.assertEquals(true, missingChannelRaised);

    MessagingComposerController.SendMessageResponse response = MessagingComposerController.sendMessageJson(
      '{"messageDefinitionName":"Template","messagingChannelId":"0Mh000000000001AAA","messagingEndUserId":"0Mj000000000001AAA"}'
    );
    System.assertEquals('Simulado', response.status);
  }

  @IsTest
  static void testDirectHelperPaths() {
    Account accountRecord = new Account(
      Name = 'Conta Helpers',
      Phone = '11 4003 8852'
    );
    insert accountRecord;

    Contact contactRecord = new Contact(
      LastName = 'Contato Helpers',
      AccountId = accountRecord.Id,
      MobilePhone = '11 97777 6666'
    );
    insert contactRecord;

    Lead leadRecord = new Lead(
      LastName = 'Lead Helpers',
      Company = 'Enerzee',
      MobilePhone = '(11) 95555-4444'
    );
    insert leadRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Oportunidade Helpers',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(10),
      AccountId = accountRecord.Id,
      IdVirtualOffice__c = 'VO-HELPERS-001'
    );
    insert opportunityRecord;

    MessagingComposerController.RecipientDTO parsedRecipient = MessagingComposerController.parseRecipient(
      '{"id":"' +
        contactRecord.Id +
        '","type":"Contact","phone":"(11) 97777-6666","name":"Contato"}'
    );
    System.assertEquals('Contact', parsedRecipient.type);
    System.assertEquals(contactRecord.Id, parsedRecipient.id);

    MessagingComposerController.SendMessageRequest contactRequest = MessagingComposerController.buildSessionRequest(
      parsedRecipient,
      null
    );
    System.assertEquals(contactRecord.Id, contactRequest.contactId);
    System.assertEquals('11977776666', contactRequest.phone);

    MessagingComposerController.RecipientDTO accountRecipient = new MessagingComposerController.RecipientDTO();
    accountRecipient.id = accountRecord.Id;
    accountRecipient.type = 'Account';
    MessagingComposerController.SendMessageRequest accountRequest = MessagingComposerController.buildSessionRequest(
      accountRecipient,
      null
    );
    System.assertEquals(accountRecord.Id, accountRequest.accountId);

    MessagingComposerController.RecipientDTO leadRecipient = new MessagingComposerController.RecipientDTO();
    leadRecipient.id = leadRecord.Id;
    leadRecipient.type = 'Lead';
    MessagingComposerController.SendMessageRequest leadRequest = MessagingComposerController.buildSessionRequest(
      leadRecipient,
      null
    );
    System.assertEquals(leadRecord.Id, leadRequest.leadId);

    MessagingComposerController.RecipientDTO opportunityRecipient = new MessagingComposerController.RecipientDTO();
    opportunityRecipient.id = opportunityRecord.Id;
    opportunityRecipient.type = 'Opportunity';
    MessagingComposerController.SendMessageRequest opportunityRequest = MessagingComposerController.buildSessionRequest(
      opportunityRecipient,
      null
    );
    System.assertEquals(accountRecord.Id, opportunityRequest.accountId);
    System.assertEquals(opportunityRecord.Id, opportunityRequest.opportunityId);

    System.assertEquals(
      accountRecord.Id,
      MessagingComposerController.resolveChannelId(
        null,
        accountRecord.Id,
        null,
        null
      )
    );
    System.assertEquals(
      accountRecord.Id,
      MessagingComposerController.resolveMessagingEndUser(
        buildDirectRequest(accountRecord.Id)
      )
    );
    System.assertEquals(
      null,
      MessagingComposerController.findExistingEndUser(
        null,
        null,
        accountRecord.Id
      )
    );
    System.assertEquals(
      null,
      MessagingComposerController.findExistingEndUserByPhone(
        '11 97777 6666',
        accountRecord.Id
      )
    );
    System.assertEquals(
      null,
      MessagingComposerController.findLatestSession(
        accountRecord.Id,
        accountRecord.Id
      )
    );

    Boolean missingChannelRaised = false;
    try {
      MessagingComposerController.resolveChannelId(null, null, null, null);
    } catch (Exception ex) {
      missingChannelRaised = true;
    }
    System.assertEquals(true, missingChannelRaised);

    System.assertEquals(
      '11 4003 8852',
      MessagingComposerController.pickPhone(accountRecord)
    );
    System.assertEquals(
      '11 97777 6666',
      MessagingComposerController.pickPhone(contactRecord)
    );
    System.assertEquals(
      '(11) 95555-4444',
      MessagingComposerController.pickPhone(leadRecord)
    );
    System.assertEquals(
      true,
      String.isNotBlank(MessagingComposerController.resolveMetadataEndpoint())
    );
  }

  private static MessagingComposerController.SendMessageRequest buildDirectRequest(
    Id idValue
  ) {
    MessagingComposerController.SendMessageRequest requestItem = new MessagingComposerController.SendMessageRequest();
    requestItem.messagingEndUserId = idValue;
    requestItem.messagingChannelId = idValue;
    requestItem.messageDefinitionName = 'Template';
    return requestItem;
  }
}
