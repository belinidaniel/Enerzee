/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-30-2026
 * @last modified by  : Daniel Belini
 * @test              : ClickSignTemplateControllerCoverageTest, ClickSignTemplateControllerTest
 **/
public with sharing class ClickSignTemplateQueueable implements Queueable, Database.AllowsCallouts {

    private Id templateId;

    public ClickSignTemplateQueueable(Id templateId) {
        this.templateId = templateId;
    }

    public void execute(QueueableContext context) {
        ClickSignService.createTemplateFromMappings(this.templateId);
    }
}
