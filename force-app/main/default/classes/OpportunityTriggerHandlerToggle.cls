/**
 * @description	 : Flow-invocable class to enable or disable OpportunityTriggerHandler
 * @author						 : Daniel Belini
 * @last modified: 2025-09-15
 */
public with sharing class OpportunityTriggerHandlerToggle {
  public class ToggleRequest {
    @InvocableVariable(required=true label='Enable Trigger?')
    public Boolean enable;
  }

  public class ToggleResponse {
    @InvocableVariable(label='Result Message')
    public String message;
  }

  @InvocableMethod(
    label='Toggle Opportunity Trigger Handler'
    description='Enable or disable OpportunityTriggerHandler dynamically from Flow.'
  )
  public static List<ToggleResponse> toggleTrigger(
    List<ToggleRequest> requests
  ) {
    List<ToggleResponse> results = new List<ToggleResponse>();

    for (ToggleRequest req : requests) {
      if (req.enable) {
        OpportunityTriggerHandler.enableTrigger();
      } else {
        OpportunityTriggerHandler.disableTrigger();
      }

      ToggleResponse res = new ToggleResponse();
      res.message =
        'OpportunityTriggerHandler was ' +
        (req.enable ? 'enabled' : 'disabled');
      results.add(res);
    }

    return results;
  }
}
