@IsTest
private class ProposalCoverTriggerHandlerTest {
    @IsTest
    static void shouldToggleTrigger() {
        ProposalCoverTriggerHandler.disableTrigger();
        System.assertEquals(false, ProposalCoverTriggerHandler.isTriggerEnabled());
        ProposalCoverTriggerHandler.enableTrigger();
        System.assertEquals(true, ProposalCoverTriggerHandler.isTriggerEnabled());
    }
}
