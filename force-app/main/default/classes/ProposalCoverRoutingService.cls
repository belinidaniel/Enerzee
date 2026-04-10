/**
 * @description       : Resolve a chave funcional da capa e define se o fluxo deve usar a API.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-10-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalEngineSupportTest
 **/
public with sharing class ProposalCoverRoutingService {
  private static final String GROUP_B_STANDARD_TEMPLATE = 'MODELOPROPOSTAB';
  private static final String GROUP_B_STANDARD_COVER_KEY = 'GRUPO_B_PADRAO';

  @TestVisible
  private static final Map<String, String> LEGACY_TEMPLATE_TO_COVER_KEY = new Map<String, String>{
    GROUP_B_STANDARD_TEMPLATE => GROUP_B_STANDARD_COVER_KEY
  };

  public static Boolean usesApiFlow(ProposalCover__c cover) {
    return String.isNotBlank(resolveCoverKey(cover));
  }

  public static String resolveCoverKey(ProposalCover__c cover) {
    if (cover == null) {
      return null;
    }
    if (String.isNotBlank(cover.IntegrationKey__c)) {
      return cover.IntegrationKey__c.trim();
    }
    if (matchesGroupBStandardFallback(cover)) {
      return GROUP_B_STANDARD_COVER_KEY;
    }
    return null;
  }

  public static String resolveCoverKeyByTemplate(String templateName) {
    if (String.isBlank(templateName)) {
      return null;
    }
    return LEGACY_TEMPLATE_TO_COVER_KEY.get(templateName.trim().toUpperCase());
  }

  private static Boolean matchesGroupBStandardFallback(ProposalCover__c cover) {
    return cover != null &&
      cover.isPromotional__c == false &&
      String.isNotBlank(cover.Template__c) &&
      cover.Template__c.trim().toUpperCase() == GROUP_B_STANDARD_TEMPLATE;
  }
}
