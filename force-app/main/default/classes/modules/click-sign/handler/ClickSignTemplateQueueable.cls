public with sharing class ClickSignTemplateQueueable implements Queueable, Database.AllowsCallouts {

    private Id templateId;

    public ClickSignTemplateQueueable(Id templateId) {
        this.templateId = templateId;
    }

    public void execute(QueueableContext context) {
        ClickSignService.createTemplateFromMappings(this.templateId);
    }
}
