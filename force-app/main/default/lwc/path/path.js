import { api, LightningElement } from 'lwc';

// Import custom labels

export default class path extends LightningElement {
    @api indicatorType;
    @api
    get stepList() {
        return this._stepList;
    }
    set stepList(value) {
        this._stepList = value;
        this.requestRecalc();
    }
    @api
    get currentStep() {
        return this._currentStep;
    }
    set currentStep(value) {
        this._currentStep = value;
        this.requestRecalc();
    }
    @api
    get currentStepPercentage() {
        return this._currentStepPercentage;
    }
    set currentStepPercentage(value) {
        this._currentStepPercentage = value;
        this.requestRecalc();
    }
    
    // Expose the labels to use in the template
    label = {
        DFP_Complete: 'Complete',
        DFP_Current: 'Current',
        DFP_Upcoming: 'Upcoming'
    };

    showTypeVertical;
    showTypeVertNav;
    showTypeHorizontal;
    showTypePath;
    showTypeBar;
    showTypeRing;

    stepsArray;
    pathProgress;

    stepPercent;
    countTotalSteps;
    countToCurrent;

    progressLabel;
    
    connectedCallback() {
        this.requestRecalc();
    }

    renderedCallback() {
        this.recalculateIfNeeded();
    }

    requestRecalc() {
        this._pendingRecalc = true;
        this.recalculateIfNeeded();
    }

    recalculateIfNeeded() {
        const indicatorDirty = this.indicatorType || '';
        const stepListValue = this._stepList || '';
        if (!indicatorDirty || !stepListValue) {
            return;
        }

        const configKey = `${indicatorDirty}|${stepListValue}|${this._currentStep || ''}|${this._currentStepPercentage || ''}`;
        if (!this._pendingRecalc && configKey === this._configKey) {
            return;
        }
        this._pendingRecalc = false;
        this._configKey = configKey;

        // clean the indicatorType variable of any leading/trailing spaces and convert to lowercase
        let indicatorClean = indicatorDirty.trim().toLowerCase();
        let considerCurrentStepPercentage = false;

        // reset indicators
        this.showTypeVertical = false;
        this.showTypeVertNav = false;
        this.showTypeHorizontal = false;
        this.showTypePath = false;
        this.showTypeBar = false;
        this.showTypeRing = false;

        // set conditions for which indicator type displays
        switch (indicatorClean) {
            case 'vertical':
                this.showTypeVertical = true;
                break;
            case 'vertnav':
                this.showTypeVertNav = true;
                break;
            case 'horizontal':
                this.showTypeHorizontal = true;
                break;
            case 'path':
                this.showTypePath = true;
                break;
            case 'bar':
                this.showTypeBar = true;
                considerCurrentStepPercentage = true;
                break;
            case 'ring':
                this.showTypeRing = true;
                considerCurrentStepPercentage = true;
                break;
            default:
                this.showTypeHorizontal = true;
                break;
        }

        // convert stepList from string of comma-separated values to an array
        const stepListArray = stepListValue.split(',');

        let countTotalSteps = stepListArray.length;
        let stepsArrayTemp = [];
        let afterCurrent = false;
        let countToCurrent = 0;
        let currentCount = 0;

        for (let i = 0; i < stepListArray.length; i++) {
            currentCount = i+1;

            let isFinalStep = false;
            if(currentCount == countTotalSteps){
                isFinalStep = true;
            }
            
            let cleanArrayValue = stepListArray[i].trim();
            
            if (afterCurrent == false) {
                
                // this step might be Completed or Current
                if (cleanArrayValue == this._currentStep) {
                    
                    if(isFinalStep == true) {
                        switch (indicatorClean) {
                            case 'vertical':
                                // this is the final step for the vertnav indicator type, but it needs to be display as Current
                        stepsArrayTemp.push({
                            'label': cleanArrayValue,
                            'status': 'Complete',
                            'showCurrent' : false,
                            'showComplete' : false,
                            'showFinalComplete' : true,
                            'showUpcoming' : false,
                            'finalStep' : true
                        });
                                break;
                            case 'vertnav':
                                // this is the final step for the vertnav indicator type, but it needs to be display as Current
                                stepsArrayTemp.push({
                                    'label': cleanArrayValue,
                                    'status': 'Complete',
                                    'showCurrent' : false,
                                    'showComplete' : false,
                                    'showFinalComplete' : true,
                                    'showUpcoming' : false,
                                    'finalStep' : true
                                });
                                break;
                            default:
                                // this is the current step, but since it is the final one, it is marked as Complete instead
                        stepsArrayTemp.push({
                            'label': cleanArrayValue,
                            'status': 'Complete',
                            'showCurrent' : false,
                            'showComplete' : true,
                            'showFinalComplete' : false,
                            'showUpcoming' : false,
                            'finalStep' : true
                        });
                                break;
                        }

                        countToCurrent++;
                    }
                    else {

                        // this is the current step, but it is not the final one (or it's the final one for the vertnav indicator type)
                        stepsArrayTemp.push({
                            'label': cleanArrayValue,
                            'status': 'Current',
                            'showCurrent' : true,
                            'showComplete' : false,
                            'showUpcoming' : false,
                            'finalStep' : false
                        });
                        
                        // set afterCurrent to true,
                        // so all subsequent steps
                        // are marked as future
                        afterCurrent = 'true';
                        countToCurrent++;
                    }
                }
                else {
                    
                    // this is a completed step
                    stepsArrayTemp.push({
                        'label': cleanArrayValue,
                        'status': 'Complete',
                        'showCurrent' : false,
                        'showComplete' : true,
                        'showUpcoming' : false,
                        'finalStep' : isFinalStep
                    });
                    countToCurrent++;
                }
            }
            else {
                
                // this is an upcoming step
                stepsArrayTemp.push({
                    'label': cleanArrayValue,
                    'status': 'Upcoming',
                    'showCurrent' : false,
                    'showComplete' : false,
                    'showUpcoming' : true,
                    'finalStep' : false
                });
            }
        }
        
        // this.countToCurrent = countToCurrent;
        // this.countTotalSteps = countTotalSteps;

        // set pathProgress to number of steps unless currentStepPercentage is set
        if(considerCurrentStepPercentage == true) {

            let percentProperty = this._currentStepPercentage;

            if(percentProperty > 0) {
                this.pathProgress = percentProperty;

                this.stepPercent = percentProperty;

                let testPercent = percentProperty;

                // need a label property for the Bar indicator type that shows completion like "45% Complete"
                this.progressLabel = `${percentProperty}% ${this.label.DFP_Complete}`;

                // setting dynamic css width value for the Bar and Ring indicator types
                document.documentElement.style.setProperty('--value', percentProperty);
            }

            else {
                this.pathProgress = (((countToCurrent-1)/(countTotalSteps-1)*100));

                // need a label property for the Bar indicator type that shows completion like "45% Complete"
                this.progressLabel = `${this.pathProgress}% ${this.label.DFP_Complete}`;

                // setting dynamic css width value for the Bar and Ring indicator types
                document.documentElement.style.setProperty('--value', this.pathProgress);
            }
        }

        // indicator type is not a bar or ring
        else {
            this.pathProgress = (((countToCurrent-1)/(countTotalSteps-1)*100));

            // need a label property for the Horizontal indicator type that shows completion like "45% Complete"
            this.progressLabel = `${this.pathProgress}% ${this.label.DFP_Complete}`;
            
            // setting dynamic css width value for the Horizontal indicator type
            document.documentElement.style.setProperty('--value', this.pathProgress);
        }

        // store list of steps to iterate over in the html
        this.stepsArray = stepsArrayTemp;
    }

    handleStepClick(event) {
        const stepValue = event.currentTarget?.dataset?.step;
        if (!stepValue) {
            return;
        }
        this.dispatchEvent(
            new CustomEvent('stepchange', {
                detail: { value: stepValue },
                bubbles: true,
                composed: true
            })
        );
    }
}