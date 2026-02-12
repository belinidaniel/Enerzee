@IsTest
private class TriggerHandlerTest {
    private class DummyHandler extends TriggerHandler {
        public Boolean beforeInsertCalled = false;
        public Boolean afterInsertCalled = false;
        public Boolean beforeUpdateCalled = false;
        public Boolean afterUpdateCalled = false;
        public Boolean beforeDeleteCalled = false;
        public Boolean afterDeleteCalled = false;

        DummyHandler(System.TriggerOperation op) {
            super(op, new List<SObject>(), new List<SObject>(), new Map<Id, SObject>(), new Map<Id, SObject>());
        }

        public override void beforeInsert(){ beforeInsertCalled = true; }
        public override void afterInsert(){ afterInsertCalled = true; }
        public override void beforeUpdate(){ beforeUpdateCalled = true; }
        public override void afterUpdate(){ afterUpdateCalled = true; }
        public override void beforeDelete(){ beforeDeleteCalled = true; }
        public override void afterDelete(){ afterDeleteCalled = true; }
    }

    @IsTest
    static void shouldDispatchOperations() {
        DummyHandler handler = new DummyHandler(System.TriggerOperation.BEFORE_INSERT);
        handler.execute();
        System.assert(handler.beforeInsertCalled);

        handler = new DummyHandler(System.TriggerOperation.AFTER_INSERT);
        handler.execute();
        System.assert(handler.afterInsertCalled);

        handler = new DummyHandler(System.TriggerOperation.BEFORE_UPDATE);
        handler.execute();
        System.assert(handler.beforeUpdateCalled);

        handler = new DummyHandler(System.TriggerOperation.AFTER_UPDATE);
        handler.execute();
        System.assert(handler.afterUpdateCalled);

        handler = new DummyHandler(System.TriggerOperation.BEFORE_DELETE);
        handler.execute();
        System.assert(handler.beforeDeleteCalled);

        handler = new DummyHandler(System.TriggerOperation.AFTER_DELETE);
        handler.execute();
        System.assert(handler.afterDeleteCalled);
    }
}
