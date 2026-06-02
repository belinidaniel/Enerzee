/**
 * @description       : Helper sem sharing para ler os aprovadores (Supervisor/Gerente) do Contato em contexto de sistema. Necessário porque o caso pode ser criado por usuário Guest do portal,
 *                       que não enxerga o Contact via sharing — então a leitura precisa ignorar o sharing do usuário.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-02-2026
 * @last modified by  : Daniel Belini
 * @test              : CaseBOTest, CaseTriggerTest, HelpDeskCaseServiceTest, ModuloHelpDeskCaseControllerTest
 **/
public without sharing class HelpDeskApproverHelper {
  /**
   * Retorna um mapa de Contact Id -> Contact (com Supervisor__c/Gerente__c),
   * lido sem as restrições de sharing do usuário atual.
   */
  public static Map<Id, Contact> getApproversByContact(Set<Id> contactIds) {
    if (contactIds == null || contactIds.isEmpty()) {
      return new Map<Id, Contact>();
    }
    return new Map<Id, Contact>(
      [
        SELECT
          Id,
          Supervisor__c,
          Supervisor__r.Name,
          Gerente__c,
          Gerente__r.Name
        FROM Contact
        WHERE Id IN :contactIds
      ]
    );
  }

  /**
   * Resolve os nomes de usuários (Id -> Name) em contexto de sistema.
   * Necessário porque o usuário Guest do portal não tem acesso de leitura
   * ao objeto User, então Supervisor__r.Name etc. retornam um placeholder.
   */
  public static Map<Id, String> getUserNames(Set<Id> userIds) {
    Map<Id, String> names = new Map<Id, String>();
    if (userIds == null || userIds.isEmpty()) {
      return names;
    }
    userIds.remove(null);
    if (userIds.isEmpty()) {
      return names;
    }
    for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds]) {
      names.put(u.Id, u.Name);
    }
    return names;
  }
}
