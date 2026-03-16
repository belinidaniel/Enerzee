/**
 * @description       :
 * @author            : daniel
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
public with sharing class FeedbackControllerTest {
  @TestSetup
  static void makeData() {
    Feedback__c feedback = new Feedback__c(
      Score__c = '5',
      Notes__c = 'Initial Notes'
    );
    insert feedback;
  }

  public FeedbackControllerTest() {
  }

  @isTest
  static void testGetEventsBySubject() {
    // Setup test data
    feedback__c feedback = [SELECT Id FROM Feedback__c LIMIT 1];
    Task task = new Task(Subject = 'Test Task', Feedback__c = feedback.Id);
    insert task;

    Test.startTest();
    List<Task> tasks = FeedbackController.getEventsBySubject(feedback.Id);
    Test.stopTest();
  }

  @isTest
  static void testSaveFeedback() {
    // Setup test data
    Feedback__c feedback = new Feedback__c(
      Score__c = '5',
      Notes__c = 'Initial Notes'
    );
    insert feedback;

    Test.startTest();
    String result = FeedbackController.saveFeedback(
      feedback.Id,
      '5',
      'Updated Notes'
    );
    Test.stopTest();
  }
}
