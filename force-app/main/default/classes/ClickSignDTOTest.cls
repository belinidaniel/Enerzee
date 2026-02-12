@IsTest
private class ClickSignDTOTest {
    @IsTest
    static void shouldInstantiateRequest() {
        ClickSignDTO.RequestCreateEnvelop req = new ClickSignDTO.RequestCreateEnvelop();
        req.name = 'Env';
        req.locale = 'pt-BR';
        req.auto_close = true;
        req.remind_interval = 3;
        req.deadline_at = '2026-01-01';
        req.default_subject = 'Assinatura';
        req.default_message = 'Mensagem';

        System.assertEquals('Env', req.name);
        System.assertEquals(true, req.auto_close);
    }
}
