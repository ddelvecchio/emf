package gov.epa.emissions.framework.client.cost.controlmeasure;

import gov.epa.emissions.framework.services.EmfException;
import gov.epa.emissions.framework.services.cost.ControlMeasure;

public class EditableCMSummaryTabPresenterImpl implements ControlMeasureTabPresenter {

    private ControlMeasureTabView view;

    public EditableCMSummaryTabPresenterImpl(ControlMeasureTabView view) {
        this.view = view;
    }

    public void doSave(ControlMeasure measure) throws EmfException {
        view.save(measure);
    }

    public void doRefresh(ControlMeasure measure) {
        view.refresh(measure);
    }

}
