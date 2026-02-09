@IsTest
private class VOIntegrationEmailAlertTest {
    @IsTest
    static void extractErrorMessageReturnsFallback() {
        String fallback = 'fallback';
        String result = VOIntegrationEmailAlert.extractErrorMessage(null, fallback);
        System.assertEquals(fallback, result, 'Deve retornar o fallback quando o body for nulo.');
    }

    @IsTest
    static void extractErrorMessageReturnsRetorno() {
        Map<String, Object> body = new Map<String, Object>{
            'retorno' => 'Erro no VO'
        };
        String result = VOIntegrationEmailAlert.extractErrorMessage(body, 'fallback');
        System.assertEquals('Erro no VO', result, 'Deve retornar o campo retorno quando presente.');
    }

    @IsTest
    static void sendErrorDoesNotThrowInTest() {
        VOIntegrationEmailAlert.sendError('Cliente VO', 'Conta Teste', '001000000000001', null);
        System.assert(true, 'Metodo executado sem excecao em teste.');
    }
}
