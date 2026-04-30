/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-30-2026
 * @last modified by  : Daniel Belini
 * @test              : NO_TESTS_MAPPED
 **/
public with sharing class ProductDAO {

	/**
	 * @description  Override do ID do Standard Pricebook, injetável via teste.
	 *               Evita o uso de Test.isRunningTest() em código de produção:
	 *               em testes, setar com Test.getStandardPricebookId() antes de chamar o endpoint.
	 *               Em produção, o valor é resolvido por SOQL (IsStandard = TRUE).
	 */
	@TestVisible
	static Id standardPricebookIdOverride;

	/**
	 * @description  Retorna o ID do Standard Pricebook da org.
	 *               Em produção: SOQL direto filtrando IsStandard = TRUE.
	 *               Em testes: usa o override injetado via standardPricebookIdOverride.
	 *               Lança ProductDAOException se nenhum Pricebook padrão for encontrado.
	 * @return       Id do Standard Pricebook2
	 * @throws       ProductDAOException se IsStandard = TRUE não retornar resultado
	 **/
	public static Id getStandardPricebookId() {
		if (standardPricebookIdOverride != null) {
			return standardPricebookIdOverride;
		}
		List<Pricebook2> pbs = [
			SELECT Id
			FROM Pricebook2
			WHERE IsStandard = TRUE
			WITH SECURITY_ENFORCED
			LIMIT 1
		];
		if (pbs.isEmpty()) {
			throw new ProductDAOException('Standard Pricebook not found.');
		}
		return pbs[0].Id;
	}

	/**
	 * @description  Busca Product2 por external ID de integração.
	 *               Prioriza Id_Externo__c (canônico) e mantém fallback em ExternalId__c
	 *               para compatibilidade com registros legados.
	 *               Retorna Map<String, Product2> indexado pelo valor recebido no payload.
	 *               Retorna mapa vazio se o set de entrada for vazio (sem SOQL desnecessário).
	 * @param        extIds Set de valores de externalId recebidos no PATCH
	 * @return       Map<String, Product2> indexado por externalId
	 **/
	public static Map<String, Product2> getProductsByExternalId(Set<String> extIds) {
		Map<String, Product2> result = new Map<String, Product2>();
		if (extIds.isEmpty()) return result;
		for (Product2 p : [
			SELECT Id, Name, Family, ProductCode, IsActive, ExternalId__c, Id_Externo__c, Description
			FROM Product2
			WHERE Id_Externo__c IN :extIds
			   OR ExternalId__c IN :extIds
			WITH SECURITY_ENFORCED
		]) {
			if (!String.isBlank(p.Id_Externo__c) && extIds.contains(p.Id_Externo__c)) {
				result.put(p.Id_Externo__c, p);
			}
			if (!String.isBlank(p.ExternalId__c) && extIds.contains(p.ExternalId__c) && !result.containsKey(p.ExternalId__c)) {
				result.put(p.ExternalId__c, p);
			}
		}
		return result;
	}

	/**
	 * @description  Retorna os IDs de produtos que possuem OpportunityLineItem
	 *               em Opportunity aberta (IsClosed = FALSE).
	 *               Usado pelo processUpdates para checagem em massa antes de desativar:
	 *               em vez de checar produto a produto, faz 1 SOQL para todo o batch.
	 * @param        productIds Set de IDs de Product2 a verificar
	 * @return       Set<Id> com os IDs de produtos bloqueados (com OLI ativa)
	 **/
	public static Set<Id> getBlockedProductIds(Set<Id> productIds) {
		Set<Id> blocked = new Set<Id>();
		if (productIds.isEmpty()) return blocked;
		for (OpportunityLineItem oli : [
			SELECT Product2Id
			FROM OpportunityLineItem
			WHERE Product2Id IN :productIds
			  AND Opportunity.IsClosed = FALSE
			WITH SECURITY_ENFORCED
		]) {
			blocked.add(oli.Product2Id);
		}
		return blocked;
	}

	/**
	 * @description  Retorna um Map<Product2Id, PricebookEntry> filtrado pelo pricebook informado.
	 *               Um produto pode ter apenas 1 PBE por pricebook, logo o Map é seguro (sem colisão).
	 *               Usado pelo processUpdates para decidir se cria ou atualiza a PricebookEntry.
	 * @param        productIds  Set de IDs de Product2 a consultar
	 * @param        pricebookId ID do Pricebook2 pelo qual filtrar
	 * @return       Map<Id, PricebookEntry> — chave é Product2Id
	 **/
	public static Map<Id, PricebookEntry> getPbeByProductId(
		Set<Id> productIds,
		Id pricebookId
	) {
		Map<Id, PricebookEntry> result = new Map<Id, PricebookEntry>();
		if (productIds.isEmpty()) return result;
		for (PricebookEntry pbe : [
			SELECT Id, Product2Id, UnitPrice, IsActive
			FROM PricebookEntry
			WHERE Pricebook2Id = :pricebookId
			  AND Product2Id IN :productIds
			WITH SECURITY_ENFORCED
		]) {
			result.put(pbe.Product2Id, pbe);
		}
		return result;
	}

	/**
	 * @description  Retorna todas as PricebookEntries associadas aos produtos informados,
	 *               independentemente do pricebook (Standard ou customizado).
	 *               Usado pelo processUpdates para desativar todas as PBEs ao desativar um produto.
	 * @param        productIds Set de IDs de Product2
	 * @return       List<PricebookEntry> com Id e IsActive de cada entrada
	 **/
	public static List<PricebookEntry> getAllPbeByProductIds(Set<Id> productIds) {
		if (productIds.isEmpty()) return new List<PricebookEntry>();
		return [
			SELECT Id, IsActive
			FROM PricebookEntry
			WHERE Product2Id IN :productIds
			WITH SECURITY_ENFORCED
		];
	}

	/**
	 * @description  Busca Product2 com filtros opcionais via SOQL dinâmico.
	 *               Filtros não fornecidos (null ou blank) são ignorados.
	 *               Bind vars são resolvidas pelo escopo local — sem risco de SOQL injection.
	 *               Limitado a 200 registros para evitar timeout em resposta HTTP síncrona.
	 * @param        productCode Filtro exato por ProductCode (null = ignorado)
	 * @param        family      Filtro exato por Family (null = ignorado)
	 * @param        isActive    Filtro por IsActive: true/false (null = retorna ambos)
	 * @return       List<Product2> ordenada por Name ASC, máximo 200 registros
	 **/
	public static List<Product2> searchProducts(
		String productCode,
		String family,
		Boolean isActive
	) {
		String soql = 'SELECT Id, Name, Family, ProductCode, IsActive, ExternalId__c, Id_Externo__c, Description'
			+ ' FROM Product2'
			+ ' WHERE Id != null';
		if (!String.isBlank(productCode)) soql += ' AND ProductCode = :productCode';
		if (!String.isBlank(family))      soql += ' AND Family = :family';
		if (isActive != null)             soql += ' AND IsActive = :isActive';
		soql += ' WITH SECURITY_ENFORCED ORDER BY Name ASC LIMIT 200';
		return (List<Product2>) Database.query(soql);
	}

	/**
	 * @description  Exceção interna do ProductDAO para erros de infraestrutura de dados.
	 *               Lançada quando dados essenciais (ex: Standard Pricebook) não são encontrados.
	 **/
	public class ProductDAOException extends Exception {}
}
