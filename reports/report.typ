#set document(title: "An Economic Approach to the Retention Threshold")

#align(center)[
  #text(size: 20pt, weight: "bold")[An Economic Approach to the Retention Threshold]
  #v(0.5em)
  #text(size: 11pt, style: "italic")[Applied to the Telco dataset]
  #v(0.3em)
  #text(size: 10pt)[Darius Defago · November 2026]
]

#v(2em)

= Context and stakes

In a subscription-based telecom company, churn rises past the first three months of subscription. Revenue loss is visible and the cause is identified in broad strokes, but what to do about it is less obvious. The operational question is: which subscribers should be contacted first?

Answering it requires answering a finer question. Above what probability of departure does sending a retention offer become worthwhile? Too low a threshold wastes offers on subscribers who would have stayed. Too high a threshold misses subscribers who could have been kept. The right answer is not the same depending on the value of a subscriber in the portfolio, the cost of a retention action, and its real efficacy.

The classical approach is to train a predictive model and pick a threshold from a statistical constraint, often a precision constraint. The method has the merit of simplicity but says nothing about the amounts at stake. Two classification errors weigh the same under it, when one costs the price of a wasted offer and the other the price of a lost subscriber.

The analysis that follows reframes threshold selection as a monetary question. It applies the method to IBM's public Telco dataset. The recommendation that comes out of it runs against the usual intuition.

The scope covered here is residential subscribers.

= Churn risk analysis

One fact stands out immediately from the analysis: churn risk is not spread evenly across the lifetime of a subscription. It is very high in the first months, then drops sharply and settles at a low level. A subscriber past the one-year mark is unlikely to leave, whereas a subscriber in their third month sits in the thick of the risk period.

#figure(
  image("figures/fig1_churn_by_tenure_en.png", width: 100%),
  caption: [Churn rate by tenure bracket, computed on the full Telco dataset.],
)

Contract type weighs almost as much. A subscriber on a monthly contract is nearly four times more likely to leave than one on a yearly contract, and roughly fifteen times more than one on a two-year contract. This is hardly a surprise, since a short contract leaves more freedom to walk away.

Three other factors stand out, each tied to a higher risk: fibre optic, paperless billing, and payment by electronic check. These three markers tend to go together, and the profile that emerges is that of a more digital subscriber, one who manages their services online and whose contractual relationship runs without paper or intermediary, which makes comparing offers and leaving easier.

Conversely, subscribers who sign up for add-on services such as tech support or online security leave less often. This observation calls for caution. The subscribers who take these options are likely already more invested in the relationship to begin with. The add-on accompanies loyalty but does not necessarily cause it. The shortcut of systematically pushing more add-ons on every subscriber would not necessarily reproduce the observed effect.

What follows relies on a predictive model that uses these markers and their combinations to estimate, for each subscriber, the probability of cancellation in the coming months. This probability is not a certainty but a sorting tool. It lets us decide, in an informed way, who to contact first.

= Approach

The question is: above what probability of departure does sending a retention offer become worthwhile? It is a monetary question before it is a statistical one. Answering it means weighing a spend. Before sending an offer to a subscriber, you consider what you spend to send it and what you earn if it works.

Four elements go into this calculation.

The first is what you earn by keeping a subscriber who was about to leave. Not their gross revenue, but the margin they leave to the company once variable costs are deducted. A subscriber billing 70 CHF a month is not worth 70 CHF to the company, they are worth the share of those 70 CHF that remains after paying for the network, support, licences, and commissions.

The second is the time over which you recover that margin. A subscriber kept today does not pay back over one month, they pay back over the horizon during which they remain a customer. That horizon is not infinite, subscribers eventually leave for reasons other than those at hand here. Choosing this horizon is a real choice, detailed in the appendix.

The third is the cost of the retention action itself. An offer has a price: the discount granted, the call made by an agent, the mailing of a letter, or some combination of the three. This cost is incurred whether the offer works or not.

The fourth is the probability that the offer actually works, meaning that it keeps a subscriber who would otherwise have left. This probability is central. An offer that works one time in three does not have the same profitability as one that works two times in three, at the same cost.

These four elements combine. The expected value of a retention action, for a given subscriber, depends on the probability of departure without intervention, the gain if they stay, and the cost incurred either way. By setting a probability threshold above which we act, we implicitly choose a balance between these quantities. A low threshold triggers many actions, some on subscribers who would have stayed regardless, which dilutes the gain. A high threshold acts only on the riskiest cases, at the cost of letting go subscribers who could have been kept. The right threshold is the one that maximises the total net value of the campaign, not the one that maximises a statistical metric with no monetary counterpart.

Applying this reasoning requires knowing the four elements. Three of them cannot be read from the Telco dataset with sufficient precision, because they depend either on the economic structure of the market (the typical contribution margin in the sector) or on the expected efficacy of a commercial action not yet carried out (the cost of an offer, its success rate). These three elements must be set as assumptions, drawn from reasonable and verifiable market benchmarks. The fourth, the time over which the value of a kept subscriber is recovered, is of a different nature. It can be estimated directly from the data, since it comes down to observing how long subscribers actually stay.

= Economic assumptions

The market benchmarks adopted for the three assumed elements are the following, as plausible orders of magnitude for a European telecom operator in 2026.

The contribution margin of a subscriber sits between 55 and 70% of billed revenue#footnote[The per-subscriber contribution margin, which only retains costs that vary with the subscriber's presence, differs from group-level EBITDA margin. The EBITDA margins published by European operators in 2026 sit between 35 and 45% (Swisscom, Salt, Deutsche Telekom, Bouygues Telecom, annual reports 2025-2026), but include fixed costs independent of individual churn. The range adopted here is consistent with sector benchmarks from Analysys Mason and GSMA Intelligence.]. The gap between the two bounds reflects real differences between operators, depending on the share of owned network, the structure of support costs, and the services mix. For a subscriber at 70 CHF a month, this corresponds to a monthly margin of between 39 and 49 CHF.

The cost of a proactive retention action sits between 25 and 60 CHF per subscriber contacted#footnote[2026 European benchmark on call centre costs: 2 to 8 euros per contact, 25 to 45 euros per agent hour (Yoummday, market analysis July 2026). The upper end includes the value of the offer itself, discount or commercial concession, on top of the contact cost.]. The range covers common combinations of an outbound call, a discount applied over a few months, or a one-off commercial concession. This cost is incurred whether the offer works or not.

The success rate of a proactive offer, that is the probability that a subscriber receiving an offer actually stays, sits between 20 and 35%#footnote[Proactive contact reduces churn by 15 to 25% according to 2026 sector benchmarks (Growsurf, Customer Churn Statistics 2026). A study published in MDPI in January 2026 on an outbound telecom campaign estimates revenue preservation at 10% over 12 months for a pilot of 5,000 at-risk subscribers per month.]. This figure warrants a note of caution. Figures published by operators are sometimes much more flattering, but they often come from inbound retention teams, who handle calls from subscribers coming in to report their intent to leave#footnote[A documented case of a US telecom operator (Foundever 2024 case study) shows a save rate of 65 to 70% for an inbound retention team, a figure representative of the sector and confirming the gap with proactive outbound.]. These callers are already on their way out, and the negotiation is about what to concede to hold them back. The context differs from the one at hand here, where the offer is sent proactively to a subscriber who did not ask for anything. Success rates for proactive outbound are consistently lower than those for inbound retention, and the range adopted here reflects that gap.

The fourth element is the horizon over which the margin of a kept subscriber is recovered. It is tempting to take the average tenure of current subscribers and use it as the horizon. That would be a mistake. The "Churn risk analysis" section established that departure risk is heavily concentrated in the first months, then drops. A subscriber who leaves after two months and one who stays five years are not two instances of the same phenomenon, they are two different populations. The approach adopted here estimates the horizon with a method that respects the shape of risk over time, accounting for the fact that early departures weigh differently from late ones. The method is detailed in the appendix. In practice, the result gives a horizon of about 55 months for a subscriber past the initial risk zone, slightly more than four and a half years. This order of magnitude is consistent with the sector, where a stabilised subscriber typically stays between three and six years.

Three of the four elements are therefore given as ranges. Rather than picking a single point in the middle of each and resting the whole recommendation on that choice, we work with three scenarios. A conservative scenario, which combines the bounds unfavourable to the action's profitability: low margin, high offer cost, low success rate. An optimistic scenario, which takes the opposite bounds. A central scenario, which takes the median position of each range. If the recommendation differs noticeably between the three, that means the assumptions drive the result and they will need to be tightened before acting. If it is roughly the same, the recommendation is robust and can be adopted without waiting to reduce market uncertainties.

= Results and recommendation

Applying the method to the dataset gives a central business threshold of 7%. It rises to 11% under the conservative scenario, and drops to 6% under the optimistic scenario. The strategy is consistent across the three scenarios.

This threshold designates about 70% of the portfolio as candidates for a retention offer. The expected net gain of the campaign, that is the margin saved minus the total cost of offers sent, sits between 100,000 CHF under the conservative scenario and 330,000 CHF under the optimistic one, with the central scenario around 195,000 CHF.

The size of the target is unexpected. One would expect a rigorous method to tighten the target, not to widen it to seven subscribers out of ten. Yet that is the right approach: a saved subscriber brings in on average 2,000 CHF of margin over the time they remain a customer, against an offer cost of 40 CHF. Fifty wasted offers cost what a single lost subscriber would have brought in. The asymmetry is such that acting remains profitable even when there is only a 7% chance that the subscriber was going to leave.

To measure what the monetary method gains, you can compare it to the most defensible statistical practice. The latter requires that at least half of the subscribers contacted actually be leavers, then targets as widely as possible under that constraint. Applied to the same dataset, it designates 44% of subscribers and yields a net gain of 176,000 CHF. The gap with the monetary method is 19,000 CHF, or 10% of the accessible value. A model optimised by standard statistical practice thus leaves a tenth of the value on the table. Rigour is not what is lacking. What the model is missing is the price of the errors it arbitrates.

The move from 44% to 70% of the portfolio contacted sums up the difference. A reasonable statistical criterion stops the arbitration at 44% because beyond that the precision of targeting becomes too low. A monetary criterion carries on to 70% because each additional subscriber targeted, even with a lower probability of leaving, still has an expected saved value that exceeds the cost of an offer.

In practice, the subscribers designated by the threshold are not all handled at once. The list is worked through in waves, starting with the highest probabilities, then moving down over successive campaigns. The scoring frequency and the sizing of the retention teams set the pace. The value of the method is in providing a single, traceable criterion that applies to every campaign.

= Robustness and implementation

The recommendation is only as good as its assumptions. The sensitivity analysis tests this dependency by comparing the three scenarios. The threshold shifts between 7 and 11% depending on the scenario. The portfolio share designated sits between 57 and 77% depending on the scenario. The net gain ranges from 100,000 to 330,000 CHF, but the direction of action does not change. You should contact widely and accept many false positives. The result therefore does not hinge on a specific choice within the ranges.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (left, center, center, right),
    stroke: 0.5pt + gray,
    inset: 8pt,
    table.header(
      [*Scenario*], [*Threshold*], [*Portfolio targeted*], [*Expected net gain*],
    ),
    [Conservative], [11%], [57%], [103,800 CHF],
    [Central],      [7%],  [70%], [195,300 CHF],
    [Optimistic],   [6%],  [77%], [330,900 CHF],
  ),
  caption: [Synthetic comparison of the three scenarios. All three converge on the direction (contact widely), but the threshold and targeted share move with the assumptions. The net gain varies by a factor of three between conservative and optimistic.],
)

Two assumptions weigh more than the other two. The cost of an offer, which directly sets the expense of each contact. The real success rate, which determines how many targeted subscribers are actually kept. The contribution margin and the value horizon play a role too, but their effect is more modest within the adopted ranges. If the offer cost rose from 40 to 60 CHF, or if the success rate fell from 27 to 20%, the recommendation would slide towards the conservative scenario without changing in nature.

These two assumptions are among the easiest to verify in a campaign. The real cost per subscriber contacted can be read from the invoices of the teams and channels involved. For the real success rate, you follow a cohort of contacted subscribers and a comparable uncontacted cohort over six to twelve months. The margin and the horizon require more effort to recalibrate, but they are more stable over time, and an annual review is enough.

On the execution side, the model scores the whole portfolio periodically and produces, for each subscriber, a calibrated probability of cancellation. Subscribers above the threshold are added to the retention list, sorted by decreasing probability. The teams work through it in waves, starting from the top. The teams' capacity sets the pace. Each campaign records the offers sent and their outcomes after the measurement window, and these outcomes feed back into a two-level loop: the calibration of the model, and the update of the economic assumptions.

The system sharpens as it runs. The first campaign rests on market assumptions, the following ones on the measurements drawn from the previous ones. If internal measurements contradict the market benchmarks, the internal ones prevail, since they describe the company's own reality. When they confirm them, the method mainly gains in credibility.

= Conclusion

The selection of a retention target is better treated as an economic decision than as a statistical adjustment. The two approaches lead to different lists, and the economic gap between them is around 10% under the most defensible practice, more under common ones. The gain lies in the objective set for the model, not in its sophistication.

The decision-maker can draw a simple decision from this. Launch a first retention campaign under the central scenario, starting with the subscribers whose probability is highest. Measure the real success rate on this first wave by comparing the contacted cohort to a comparable cohort left aside. At the end of the six to twelve months of measurement, decide whether the central scenario holds, or whether it needs tightening towards the conservative one.

Three caveats come with this recommendation. The model was trained on a public dataset representative of a standard consumer operator, not on the company's own data. Before any deployment, it will need to be retrained on internal data and its calibration verified. The method assumes the market remains in its current configuration. A competitive disruption, a major pricing shift, or the arrival of a new entrant would alter the economic assumptions and force a recalibration. Lastly, the B2B portfolio is not covered by this analysis. The churn dynamics there differ and call for a separate analysis.

= Appendix A: model and calibration

The classifier is a binary supervised model trained on the Telco dataset (7,043 subscribers, 20 variables, 26.5% churn). Three models were compared during the exploratory phase. Logistic regression serves as the baseline and reaches a ROC AUC around 0.82, with an F1 of 0.61 on the churn class. It shows that the structure of the problem remains fairly linear once one-hot encoding is applied. The Random Forest brings no significant gain, which confirms the absence of complex interactions to capture. XGBoost was adopted for the final version. It better captures the non-linearity in the relationship between tenure and churn, in particular the fact that the risk is heavily concentrated in the first months then drops. It handles sparsely populated one-hot variables without issue and reaches a ROC AUC of 0.848 on the test set.

The hyperparameters are tuned via `RandomizedSearchCV` over 20 iterations, with 5-fold stratified cross-validation, using ROC AUC as the optimisation criterion. The ranges explored cover maximum depth, learning rate, number of trees, and subsampling rates on both rows and columns. The search runs on only part of the training set, so that the calibration step that follows uses data the estimator has never seen.

The data splitting is done at three levels. A first 80/20 split sets aside the test set for the final evaluation. Within the training set, a second 80/20 split isolates two subsets. The first is used for hyperparameter search and model fitting. The second is kept for probability calibration. All three splits are stratified on the target variable to preserve the churn ratio in each subset. The final model combines a `CalibratedClassifierCV` with a `FrozenEstimator`, which prevents re-estimation of the underlying model during calibration.

Calibration is not a cosmetic adjustment in this project. It conditions the validity of the economic reasoning in Appendix B. Selecting the threshold in francs assumes that the probability output by the model is a true frequency: that a subscriber the model assigns a 15% probability of leaving actually has a one in six or seven chance of leaving. If this condition is not met, the formula that multiplies this probability by the value of a kept subscriber yields a number that looks like an expected gain without being one. XGBoost, like most models of its kind, produces scores whose ranking is generally good but whose absolute level can be biased, especially at the ends of the scale. The calibration step corrects this bias and makes the probabilities usable.

= Appendix B: monetary threshold selection

The decision threshold selection is treated as an economic optimisation problem. The net value of a campaign at threshold $t$ is defined as:

$ "NetValue"(t) = p_"save" times sum_(i in "TP") V_("sub",i) - C_"offer" times (|"TP"| + |"FP"|) $

where TP denotes the subscribers correctly flagged (threshold crossed and true churner), FP the subscribers flagged in error, $p_"save"$ the probability that a proactive offer keeps a true churner, $V_("sub",i)$ the discounted value of a kept subscriber, and $C_"offer"$ the unit cost of a retention action. The value per subscriber is computed at the individual level, $V_("sub",i) = "MonthlyCharges"_i times "margin" times "horizon"_m$, which accounts for the dispersion of monthly bills rather than going through an aggregate average. The optimal threshold is obtained by sweeping a grid from 0.01 to 0.99 in steps of 0.01 and keeping the value of $t$ that maximises $"NetValue"(t)$.

An analytical consistency check accompanies this numerical optimisation. On average across all subscribers, the offer becomes profitable as long as $p("churn") times p_"save" times V_"sub,mean"$ exceeds $C_"offer"$, which yields a closed-form threshold $t^* = C_"offer" / (p_"save" times V_"sub,mean")$. Comparing this closed-form threshold to the one obtained by sweeping is a useful indicator. A small gap signals satisfactory probability calibration and moderate dispersion in subscriber values. A marked gap would indicate either a calibration flaw, or a dispersion in $V_"sub"$ strong enough that the average threshold is no longer representative. On the Telco data, the two values stay close in the central scenario (0.07 for the sweep, 0.071 for the formula), which confirms the quality of the calibration.

The value horizon is estimated by the restricted mean survival time, computed from a Kaplan-Meier estimator applied to the tenure variable, treating churn as the event and still-active subscribers as right-censored. The estimator integrates the survival function up to a cap (72 months, the maximum value observed in the dataset) and returns a number of months weighted by the conditional probability of survival at each instant. On the full dataset, the value obtained is 54.5 months.

#figure(
  image("figures/fig2_survival_km_en.png", width: 100%),
  caption: [Survival function estimated by Kaplan-Meier on subscriber tenure. The area under the curve between 0 and 72 months gives the restricted mean survival time of 54.5 months.],
)

Three naive approaches would have been simpler but wrong. The average tenure of currently observed subscribers (32 months on this dataset) underestimates the real horizon because it heavily includes subscribers still in their lifetime, whose final duration will necessarily exceed the one measured today. The average tenure of only subscribers who have already left (18 months) describes a population biased towards early departures, which bears no relation to the horizon of a subscriber one is trying to stabilise. The inverse of the monthly churn rate (122 months) assumes a constant departure risk over time, which the data contradicts. The restricted mean survival time avoids these three pitfalls because it makes no assumption about the shape of risk over time.

The three assumed parameters are declined into three scenarios that bound the recommendation. The conservative scenario combines a low margin (0.55), a high offer cost (60 CHF), and a low success rate (0.20). The optimistic scenario combines the opposite bounds (0.70, 25 CHF, 0.35). The central scenario takes the median position (0.60, 40 CHF, 0.27). The restricted mean survival time is shared across the three scenarios, since it is estimated from the data and not assumed.

A sensitivity analysis on the horizon alone completes the picture. It multiplies the restricted mean survival time by factors of 0.6 to 1.4 and checks that the optimal threshold of the central scenario does not move markedly over that range. It covers both the uncertainty on the choice of the upper bound and the effect of an implicit financial discounting. On the Telco data, the threshold stays stable within this range, which confirms that the recommendation does not depend on a specific choice of horizon.

= Appendix C: inference pipeline

The code is organised into four files, each responsible for one step. The `preprocessing.py` file holds the feature transformations, in particular the encoding, type cleaning, and the realignment on an expected column schema. The `train.py` file orchestrates training, calibration, and evaluation. The `business_value.py` file isolates the economic reasoning, that is the threshold selection, the scenario definitions, and the sensitivity analyses. The `predict.py` file consumes the artefacts produced at training and returns the flags for a list of subscribers given as input. The four files share only clean interfaces, and no business logic is duplicated between them.

Three objects are serialised at the end of training: the calibrated model (`model.pkl`), the schema of columns expected in input (`columns.pkl`), and a dictionary of thresholds by scenario, each with the economic assumptions that produced them (`threshold.pkl`). The inference step reloads these three objects and applies them to a subscriber file in batch, with an explicit scenario choice (conservative, central, optimistic) passed as a command-line argument. The retention team can therefore replay the same list under several scenarios without having to retrain, which is useful for comparing target sizes and expected gains before deciding.

The schema validation at inference is strict and designed not to fail silently. If an expected column is missing from the input file, the code raises an explicit exception before any call to the model. This discipline avoids what is probably the most costly flaw in a production prediction code: the silently wrong prediction, where the model receives a feature vector aligned on a wrong schema and returns a probability that means nothing. An explicit failure at the input turns this kind of problem into an immediate and visible incident rather than a drift that contaminates successive campaigns.

The traceability of economic assumptions down to the individual prediction is the pipeline's most specific feature. The threshold file does not just carry the numeric threshold values. For each scenario, it also embeds the four assumptions that produced them: contribution margin, offer cost, expected success rate, and value horizon. A flagged subscriber can therefore be explained after the fact by tracing from the flag back to the probability, then to the threshold, then to the assumptions and the scenario under which it was produced. This chain of traceability is useful for internal audit, for assumption review, and when switching from one scenario to another.