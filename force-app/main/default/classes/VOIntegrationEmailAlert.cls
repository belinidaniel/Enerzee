public with sharing class VOIntegrationEmailAlert {
    private static final List<String> ALERT_RECIPIENTS = new List<String>{
        'daniel.belini@enerzee.com.br',
        'jean.carlos@enerzee.com.br'
    };

    public static void sendError(
        String integrationName,
        String recordLabel,
        Id recordId,
        String message
    ) {
        if (Test.isRunningTest()) {
            return;
        }

        if (String.isBlank(message)) {
            message = 'Erro desconhecido na integracao com Virtual Office.';
        }

        String subject = 'Erro integracao VO - ' + integrationName;
        String body = 'Integracao: ' + integrationName + '\n';
        if (String.isNotBlank(recordLabel)) {
            body += 'Registro: ' + recordLabel + '\n';
        }
        if (recordId != null) {
            body += 'Id: ' + String.valueOf(recordId) + '\n';
            body += 'Link: ' + URL.getOrgDomainUrl().toExternalForm() + '/' + recordId + '\n';
        }
        body += 'Mensagem: ' + message;

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(ALERT_RECIPIENTS);
        email.setSubject(subject);
        email.setPlainTextBody(body);

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }

    public static String extractErrorMessage(Map<String, Object> responseBody, String fallback) {
        if (responseBody == null) {
            return fallback;
        }

        Object retorno = responseBody.get('retorno');
        if (retorno == null) {
            return fallback;
        }

        String retornoText = String.valueOf(retorno);
        if (String.isBlank(retornoText)) {
            return fallback;
        }

        return retornoText;
    }
}
