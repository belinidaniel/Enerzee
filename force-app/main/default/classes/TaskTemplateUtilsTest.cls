@IsTest
private class TaskTemplateUtilsTest {

    @IsTest
    static void shouldCombineDateAndTime() {
        Date d = Date.newInstance(2025, 1, 1);
        DateTime result = TaskTemplateUtils.combineDateAndTime(d, Time.newInstance(10, 30, 0, 0));
        System.assertEquals(DateTime.newInstance(2025, 1, 1, 10, 30, 0), result);
    }

    @IsTest
    static void shouldParseIntegerWithFallback() {
        System.assertEquals(5, TaskTemplateUtils.parseInteger('5', 1));
        System.assertEquals(1, TaskTemplateUtils.parseInteger('abc', 1));
    }
}