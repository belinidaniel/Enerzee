@IsTest
private class CheckBusinessHourTest {

    @IsTest
    static void shouldReturnTrueDuringTest() {
        List<Boolean> result = CheckBusinessHour.makeGetCallout(new List<String>{'AnyName'});
        System.assertEquals(true, result[0]);
    }
}
