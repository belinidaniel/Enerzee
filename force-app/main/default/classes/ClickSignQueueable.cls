/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : ClickSignQueueableTest
 **/
public with sharing class ClickSignQueueable implements Queueable {
  private List<ClickSignLog__c> logs;

  public ClickSignQueueable(ClickSignLog__c log) {
    this.logs = new List<ClickSignLog__c>{ log };
  }

  public ClickSignQueueable(List<ClickSignLog__c> logs) {
    this.logs = logs;
  }

  public void execute(QueueableContext context) {
    insert this.logs;
  }
}
