/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class FormularioPDFControllerTest {
  @IsTest
  static void shouldInstantiateController() {
    FormularioPDFController controller = new FormularioPDFController();
    System.assertNotEquals(null, controller);
  }
}
