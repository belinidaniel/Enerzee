/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 09-19-2025
 * @last modified by	 : Daniel Belini
 **/
@isTest
public with sharing class OpportunityTriggerHandlerToggleTest {
  @isTest
  static void testToggleTrigger() {
    // Preparar requisições de teste
    OpportunityTriggerHandlerToggle.ToggleRequest enableReq = new OpportunityTriggerHandlerToggle.ToggleRequest();
    enableReq.enable = true;

    OpportunityTriggerHandlerToggle.ToggleRequest disableReq = new OpportunityTriggerHandlerToggle.ToggleRequest();
    disableReq.enable = false;

    Test.startTest();
    // Executa enable
    List<OpportunityTriggerHandlerToggle.ToggleResponse> enableResult = OpportunityTriggerHandlerToggle.toggleTrigger(
      new List<OpportunityTriggerHandlerToggle.ToggleRequest>{ enableReq }
    );

    // Executa disable
    List<OpportunityTriggerHandlerToggle.ToggleResponse> disableResult = OpportunityTriggerHandlerToggle.toggleTrigger(
      new List<OpportunityTriggerHandlerToggle.ToggleRequest>{ disableReq }
    );
    Test.stopTest();

    // Valida enable
    System.assertEquals(
      1,
      enableResult.size(),
      'Deve retornar 1 resposta para enable'
    );
    System.assert(
      enableResult[0].message.contains('enabled'),
      'Mensagem deve conter "enabled"'
    );

    // Valida disable
    System.assertEquals(
      1,
      disableResult.size(),
      'Deve retornar 1 resposta para disable'
    );
    System.assert(
      disableResult[0].message.contains('disabled'),
      'Mensagem deve conter "disabled"'
    );
  }
}
