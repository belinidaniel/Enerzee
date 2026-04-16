/**
 * @description       : Resolve a chave funcional da capa e define se o fluxo deve usar a API.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-15-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalEngineSupportTest
 **/
public with sharing class ProposalCoverRoutingService {
  public static Boolean usesApiFlow(ProposalCover__c cover) {
    return String.isNotBlank(resolveCoverKey(cover));
  }

  public static String resolveCoverKey(ProposalCover__c cover) {
    if (cover == null) {
      return null;
    }
    // Fluxo API: apenas quando TemplateUrl__c estiver preenchida
    if (String.isNotBlank(cover.TemplateUrl__c)) {
      return String.isNotBlank(cover.IntegrationKey__c)
        ? cover.IntegrationKey__c.trim()
        : 'API';
    }
    // Sem URL → fluxo legado (VF page)
    return null;
  }

  public static String resolveCoverKeyByTemplate(String templateName) {
    return null;
  }
}
