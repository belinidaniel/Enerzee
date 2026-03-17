/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : HelpDeskCaseServiceTest, HelpDeskFilePayloadTest, ModuloHelpDeskCaseControllerTest
 **/
public with sharing class HelpDeskFilePayload {
  @AuraEnabled
  public String fileName;
  @AuraEnabled
  public String contentType;
  @AuraEnabled
  public String base64Data;
  @AuraEnabled
  public String humanSize;
  @AuraEnabled
  public String name;
}
