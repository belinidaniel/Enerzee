/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ViabilityStudyControllerTest {
  @IsTest
  static void shouldReturnLocation() {
    Opportunity opportunity = (Opportunity) TestFactory.createSObject(
      new Opportunity(),
      true
    );

    ViabilityStudy__c study = new ViabilityStudy__c(
      Opportunity__c = opportunity.Id,
      LocalizacaoFixa__Latitude__s = -23.55,
      LocalizacaoFixa__Longitude__s = -46.63
    );
    insert study;

    Map<String, Object> result = ViabilityStudyController.getLocation(study.Id);
    Assert.isNotNull(result.get('Name'));
    Assert.areEqual(-23.55, result.get('Latitude'));
  }
}
