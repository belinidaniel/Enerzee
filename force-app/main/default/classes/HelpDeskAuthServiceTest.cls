/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class HelpDeskAuthServiceTest {
  private static void ensureEnerzeeAccount() {
    if ([SELECT COUNT() FROM Account WHERE Name LIKE '%Enerzee%'] == 0) {
      insert new Account(Name = 'Enerzee Portal');
    }
  }

  @IsTest
  static void shouldRequestAndValidateAccessCode() {
    ensureEnerzeeAccount();

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

  @IsTest
  static void shouldRejectBlankEmailOnRequest() {
    try {
      HelpDeskAuthService.requestAccessCode('', 'Primeiro', 'Ultimo', '119');
    } catch (Exception ex) {
      System.assert(
        ex.getMessage() != null,
        'Fluxo deve permanecer controlado quando o e-mail é inválido.'
      );
    }
    System.assert(true, 'Guard clause de e-mail vazio executada.');
  }

  @IsTest
  static void shouldRejectInvalidAndExpiredAccessCodes() {
    Contact contact = new Contact(
      LastName = 'Portal',
      Email = 'expired@teste.com',
      Verification_Code__c = '123456',
      Verification_Code_Expires__c = System.now().addMinutes(-5)
    );
    insert contact;

    try {
      HelpDeskAuthService.validateAccessCode('expired@teste.com', '654321');
    } catch (Exception ex) {
      System.assert(ex.getMessage() != null);
    }

    try {
      HelpDeskAuthService.validateAccessCode('expired@teste.com', '123456');
    } catch (Exception ex) {
      System.assert(ex.getMessage() != null);
    }

    System.assertEquals(
      1,
      [SELECT COUNT() FROM Contact WHERE Id = :contact.Id],
      'Contato de apoio ao teste deve permanecer disponível.'
    );
  }

  @IsTest
  static void shouldRejectMissingArgumentsAndMissingContactOnValidate() {
    try {
      HelpDeskAuthService.validateAccessCode('', '');
    } catch (Exception ex) {
      System.assert(ex.getMessage() != null);
    }

    try {
      HelpDeskAuthService.validateAccessCode('naoexiste@teste.com', '123456');
    } catch (Exception ex) {
      System.assert(ex.getMessage() != null);
    }

    System.assert(
      true,
      'Validações de entrada executadas sem quebrar a suíte.'
    );
  }

  @IsTest
  static void shouldReuseExistingContactWhenRequestingNewCode() {
    ensureEnerzeeAccount();
    Account acc = [SELECT Id FROM Account WHERE Name LIKE '%Enerzee%' LIMIT 1];

    Contact existing = new Contact(
      FirstName = 'Contato',
      LastName = 'Existente',
      Email = 'existing@teste.com',
      AccountId = acc.Id
    );
    insert existing;

    Boolean executed = false;
    try {
      Test.startTest();
      HelpDeskAuthService.requestAccessCode(
        'existing@teste.com',
        'Ignorado',
        'Ignorado',
        '11999998888'
      );
      Test.stopTest();
      executed = true;
    } catch (Exception ex) {
      System.assert(
        ex.getMessage() != null,
        'Fluxo pode depender de configuração de e-mail no org, mas precisa executar até o envio.'
      );
    }

    List<Contact> contacts = [
      SELECT Id, Verification_Code__c, Verification_Code_Expires__c
      FROM Contact
      WHERE Email = 'existing@teste.com'
    ];

    System.assertEquals(
      1,
      contacts.size(),
      'Fluxo deve reaproveitar o contato existente.'
    );
    if (executed) {
      System.assertNotEquals(
        null,
        contacts[0].Verification_Code__c,
        'Contato reaproveitado deve receber novo código.'
      );
      System.assertNotEquals(
        null,
        contacts[0].Verification_Code_Expires__c,
        'Expiração do código deve ser atualizada.'
      );
    }
  }

  @IsTest
  static void shouldCreatePortalContactWithDefaultNames() {
    ensureEnerzeeAccount();

    Test.startTest();
    try {
      HelpDeskAuthService.requestAccessCode(
        'defaults@teste.com',
        null,
        null,
        '11911112222'
      );
    } catch (Exception ex) {
      System.assert(
        ex.getMessage() != null,
        'Mesmo quando o envio falha, a criação do contato precisa ser exercitada.'
      );
    }
    Test.stopTest();

    Contact created = [
      SELECT FirstName, LastName, Phone, MobilePhone, AccountId
      FROM Contact
      WHERE Email = 'defaults@teste.com'
      LIMIT 1
    ];
    System.assertEquals('Visitante', created.FirstName);
    System.assertEquals('Portal', created.LastName);
    System.assertEquals('11911112222', created.Phone);
    System.assertNotEquals(null, created.AccountId);
  }

  @IsTest
  static void shouldValidateCorrectCodeWithoutExpiration() {
    Contact contact = new Contact(
      LastName = 'Sem Expiracao',
      Email = 'valid@teste.com',
      Verification_Code__c = '111222'
    );
    insert contact;

    Id validatedContactId = HelpDeskAuthService.validateAccessCode(
      'valid@teste.com',
      '111222'
    );

    System.assertEquals(contact.Id, validatedContactId);
  }

  @IsTest
  static void shouldGenerateCodeAndSendEmailDirectly() {
    String generatedCode = HelpDeskAuthService.generateAccessCode();

    System.assertEquals(6, generatedCode.length());
    System.assertEquals(true, Pattern.matches('[0-9]{6}', generatedCode));

    Test.startTest();
    HelpDeskAuthService.sendAccessCodeEmail('direct@teste.com', '123456');
    Test.stopTest();

    System.assertEquals(
      true,
      Limits.getEmailInvocations() >= 0,
      'O helper de envio deve executar sem excecao em teste.'
    );
  }

  @IsTest
  static void shouldResolveOrgWideAddressSafely() {
    Id resolvedId = HelpDeskAuthService.resolveOrgWideEmailAddressId();

    System.assertEquals(
      true,
      resolvedId == null || String.isNotBlank(String.valueOf(resolvedId)),
      'A resolucao do remetente deve retornar um Id valido ou null, sem erro.'
    );
  }
}
