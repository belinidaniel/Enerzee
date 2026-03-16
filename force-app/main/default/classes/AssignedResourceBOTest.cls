/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class AssignedResourceBOTest {
  @IsTest
  static void shouldAssignServiceResourceToAppointment() {
    ServiceAppointmentTriggerHandler.disableTrigger();
    // Dados mínimos
    Account acc = new Account(Name = 'Acc');
    insert acc;
    Opportunity opp = new Opportunity(
      Name = 'Opp',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(5),
      AccountId = acc.Id,
      IdVirtualOffice__c = 'vo-1'
    );
    insert opp;

    Datetime schedStart = System.now();
    ServiceAppointment app = new ServiceAppointment(
      ParentRecordId = opp.Id,
      Oportunidade__c = opp.Id,
      SchedStartTime = schedStart,
      SchedEndTime = schedStart.addMinutes(60),
      Duration = 60
    );
    insert app;

    ServiceResource sr = new ServiceResource(
      Name = 'SR Test',
      IsActive = true,
      ResourceType = 'T',
      OwnerId = UserInfo.getUserId(),
      RelatedRecordId = UserInfo.getUserId()
    );
    insert sr;

    AssignedResource ar = new AssignedResource(
      ServiceAppointmentId = app.Id,
      ServiceResourceId = sr.Id
    );

    Test.startTest();
    AssignedResourceBO.assignServiceResourceToAppointmentVisitAssignee(
      new List<AssignedResource>{ ar }
    );
    Test.stopTest();

    ServiceAppointment reloaded = [
      SELECT ResponsavelVisita__c
      FROM ServiceAppointment
      WHERE Id = :app.Id
    ];
    System.assertEquals(sr.Id, reloaded.ResponsavelVisita__c);
  }
}
