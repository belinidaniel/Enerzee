/*
 * Backfill de Projeto__c.Viabilidade__c com Opportunity.MainViability__c.
 *
 * Como usar no Execute Anonymous:
 * 1) Rode com DRY_RUN = true para validar quantidade.
 * 2) Troque para DRY_RUN = false para efetivar.
 * 3) Se "Pendentes" > 0, rode novamente.
 */
Boolean DRY_RUN = true;
Integer MAX_REGISTROS = 10000; // Limite de segurança por execução

List<Projeto__c> projetos = [
    SELECT Id, Name, Viabilidade__c, Oportunidade__c, Oportunidade__r.MainViability__c
    FROM Projeto__c
    WHERE Oportunidade__c != null
    AND Oportunidade__r.MainViability__c != null
    AND (Viabilidade__c = null OR Viabilidade__c != Oportunidade__r.MainViability__c)
    LIMIT :MAX_REGISTROS
];

System.debug(LoggingLevel.INFO, 'Projetos elegiveis nesta execucao: ' + projetos.size());

if (!DRY_RUN && !projetos.isEmpty()) {
    for (Projeto__c projeto : projetos) {
        projeto.Viabilidade__c = projeto.Oportunidade__r.MainViability__c;
    }

    Database.SaveResult[] resultados = Database.update(projetos, false);
    Integer sucesso = 0;
    Integer erro = 0;

    for (Integer i = 0; i < resultados.size(); i++) {
        if (resultados[i].isSuccess()) {
            sucesso++;
            continue;
        }

        erro++;
        for (Database.Error e : resultados[i].getErrors()) {
            System.debug(
                LoggingLevel.ERROR,
                'Falha no Projeto Id=' + projetos[i].Id + ' | Mensagem=' + e.getMessage()
            );
        }
    }

    System.debug(LoggingLevel.INFO, 'Atualizados com sucesso: ' + sucesso + ' | Com erro: ' + erro);
}

Integer pendentes = [
    SELECT COUNT()
    FROM Projeto__c
    WHERE Oportunidade__c != null
    AND Oportunidade__r.MainViability__c != null
    AND (Viabilidade__c = null OR Viabilidade__c != Oportunidade__r.MainViability__c)
];

System.debug(
    LoggingLevel.INFO,
    'Pendentes apos execucao: ' + pendentes +
    (pendentes > 0 ? ' | Rode novamente ate zerar.' : ' | Backfill concluido.')
);
