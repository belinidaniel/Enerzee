@IsTest
private class ViabilityStudyControllerTest {
    @IsTest
    static void shouldReturnLocation() {
        ViabilityStudy__c study = new ViabilityStudy__c(
            LocalizacaoFixa__Latitude__s = -23.55,
            LocalizacaoFixa__Longitude__s = -46.63
        );
        insert study;

        Map<String, Object> result = ViabilityStudyController.getLocation(study.Id);
        System.assertNotEquals(null, result.get('Name'));
        System.assertEquals(-23.55, result.get('Latitude'));
    }
}
