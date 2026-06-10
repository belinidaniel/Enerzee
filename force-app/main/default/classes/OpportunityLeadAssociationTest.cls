/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-02-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class OpportunityLeadAssociationTest {
  @IsTest
  static void shouldPreferLeadMatchingEmailAndPhone() {
    Lead leadMatchingBoth = createLead(
      'Lead Match Both',
      'match.both@example.com',
      null,
      '5511987654321'
    );
    createLead(
      'Lead Match Phone Only',
      'phone.only@example.com',
      null,
      '5511987654321'
    );

    Opportunity opp = createOpportunityForLeadMatch(
      '(11) 98765-4321',
      'MATCH.BOTH@example.com'
    );

    Test.startTest();
    OpportunityBO.assignLeadOnCreate(new List<Opportunity>{ opp });
    Test.stopTest();

    Assert.areEqual(String.valueOf(leadMatchingBoth.Id), opp.Lead__c);
  }

  @IsTest
  static void shouldMatchLeadByPhoneWhenEmailDoesNotMatch() {
    Lead leadByPhone = createLead(
      'Lead Match Phone',
      'lead.phone@example.com',
      null,
      '5511988887777'
    );

    Opportunity opp = createOpportunityForLeadMatch(
      '11 98888-7777',
      'different@example.com'
    );

    Test.startTest();
    OpportunityBO.assignLeadOnCreate(new List<Opportunity>{ opp });
    Test.stopTest();

    Assert.areEqual(String.valueOf(leadByPhone.Id), opp.Lead__c);
  }

  @IsTest
  static void shouldMatchLeadByEmailWhenPhoneIsBlank() {
    Lead leadByEmail = createLead(
      'Lead Match Email',
      'lead.email@example.com',
      null,
      null
    );

    Opportunity opp = createOpportunityForLeadMatch(
      null,
      'LEAD.EMAIL@example.com'
    );

    Test.startTest();
    OpportunityBO.assignLeadOnCreate(new List<Opportunity>{ opp });
    Test.stopTest();

    Assert.areEqual(String.valueOf(leadByEmail.Id), opp.Lead__c);
  }

  @IsTest
  static void shouldNotOverrideLeadAlreadyAssigned() {
    Lead existingLead = createLead(
      'Lead Existing',
      'existing@example.com',
      null,
      null
    );
    createLead(
      'Lead Candidate',
      'candidate@example.com',
      null,
      '5511977776666'
    );

    Opportunity opp = createOpportunityForLeadMatch(
      '11 97777-6666',
      'candidate@example.com'
    );
    opp.Lead__c = String.valueOf(existingLead.Id);

    Test.startTest();
    OpportunityBO.assignLeadOnCreate(new List<Opportunity>{ opp });
    Test.stopTest();

    Assert.areEqual(String.valueOf(existingLead.Id), opp.Lead__c);
  }

  private static Lead createLead(
    String lastName,
    String email,
    String phone,
    String mobilePhone
  ) {
    Lead leadRecord = new Lead(
      LastName = lastName,
      Company = 'Enerzee Test',
      Email = email,
      Phone = phone,
      MobilePhone = mobilePhone
    );
    insert leadRecord;
    return leadRecord;
  }

  private static Opportunity createOpportunityForLeadMatch(
    String phone,
    String email
  ) {
    return new Opportunity(
      Name = 'Opp Lead Match',
      StageName = 'Prospecção',
      CloseDate = Date.today().addDays(30),
      Telefone__c = phone,
      EmailDoResponsavel__c = email
    );
  }
}
