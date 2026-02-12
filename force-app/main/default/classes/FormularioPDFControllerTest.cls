@IsTest
private class FormularioPDFControllerTest {
    @IsTest
    static void shouldInstantiateController() {
        FormularioPDFController controller = new FormularioPDFController();
        System.assertNotEquals(null, controller);
    }
}
