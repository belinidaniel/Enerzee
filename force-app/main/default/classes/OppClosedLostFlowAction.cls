/**
 * @description       : Invocable action used by the inactivity scheduled flow to close related records even when the Opportunity trigger is temporarily disabled.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-23-2026
 * @last modified by  : Codex
 * @test              : OppClosedLostFlowActionTest
 **/
public with sharing class OppClosedLostFlowAction {
  private static final String LOSS_DESCRIPTION = 'Fechado por inatividade';
  private static final String LOSS_REASON = 'Parado por 30 dias';

  public class Request {
    @InvocableVariable(label='Run closure')
    public Boolean run;
  }

  public class Response {
    @InvocableVariable(label='Processed opportunities')
    public Integer processedCount;
  }

  @InvocableMethod(
    label='Close activities for auto Closed Lost opportunities'
    description='Closes related tasks, projects and viability studies for opportunities automatically marked as Closed Lost by inactivity.'
  )
  public static List<Response> run(List<Request> requests) {
    Boolean shouldRun = requests == null || requests.isEmpty();
    if (!shouldRun) {
      for (Request req : requests) {
        if (req != null && req.run == true) {
          shouldRun = true;
          break;
        }
      }
    }

    Response response = new Response();
    response.processedCount = 0;
    if (!shouldRun) {
      return new List<Response>{ response };
    }

    Map<Id, Opportunity> opportunitiesById = new Map<Id, Opportunity>(
      [
        SELECT Id, Name, OwnerId
        FROM Opportunity
        WHERE
          StageName = :OpportunityUtils.STATUS_FECHADO_PERDIDO
          AND DescricaoMotivoPerda__c = :LOSS_DESCRIPTION
          AND Loss_Reason__c = :LOSS_REASON
          AND LastModifiedDate = TODAY
      ]
    );

    if (opportunitiesById.isEmpty()) {
      return new List<Response>{ response };
    }

    OpportunityBO.closeActivitiesAndRelatedRecordsForClosedLost(
      opportunitiesById.keySet(),
      opportunitiesById
    );
    response.processedCount = opportunitiesById.size();
    return new List<Response>{ response };
  }
}
