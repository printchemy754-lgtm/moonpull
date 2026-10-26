package com.dwarf.godotads;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.widget.FrameLayout;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.AdSize;
import com.google.android.gms.ads.AdView;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import com.google.android.ump.ConsentInformation;
import com.google.android.ump.ConsentRequestParameters;
import com.google.android.ump.UserMessagingPlatform;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Minimal AdMob bridge for Godot 4 (Android plugin v2).
 * Banner + interstitial + rewarded, with Google UMP consent (required in the EEA/UK).
 * GDScript side: res://scripts/ads.gd
 */
public class GodotAds extends GodotPlugin {
    private static final String TAG = "GodotAds";
    private static final long RETRY_MS = 30000L;

    private final Handler main = new Handler(Looper.getMainLooper());
    private final AtomicBoolean adsStarted = new AtomicBoolean(false);

    private FrameLayout layout;
    private AdView bannerView;
    private InterstitialAd interstitial;
    private RewardedAd rewarded;
    private volatile boolean interstitialReady = false;
    private volatile boolean rewardedReady = false;
    private boolean bannerVisible = false;
    private boolean rewardEarned = false;

    private String bannerId = "";
    private String interstitialId = "";
    private String rewardedId = "";

    public GodotAds(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "GodotAds";
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo("initialized"));
        signals.add(new SignalInfo("interstitial_closed"));
        signals.add(new SignalInfo("rewarded_finished", Boolean.class));
        signals.add(new SignalInfo("ad_error", String.class));
        return signals;
    }

    @Override
    public View onMainCreate(Activity activity) {
        // Transparent overlay above the game view; holds the banner. Touches pass through.
        layout = new FrameLayout(activity);
        return layout;
    }

    // ------------------------------------------------------------------ API for GDScript

    @UsedByGodot
    public void initialize(String banner, String interstitialUnit, String rewardedUnit) {
        bannerId = banner;
        interstitialId = interstitialUnit;
        rewardedId = rewardedUnit;
        final Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        activity.runOnUiThread(() -> requestConsent(activity));
    }

    @UsedByGodot
    public void showBanner() {
        setBannerVisible(true);
    }

    @UsedByGodot
    public void hideBanner() {
        setBannerVisible(false);
    }

    @UsedByGodot
    public boolean isInterstitialReady() {
        return interstitialReady;
    }

    @UsedByGodot
    public boolean isRewardedReady() {
        return rewardedReady;
    }

    @UsedByGodot
    public void showInterstitial() {
        main.post(() -> {
            final Activity activity = getActivity();
            final InterstitialAd ad = interstitial;
            if (ad == null || activity == null) {
                emitSignal("interstitial_closed");
                return;
            }
            interstitial = null;
            interstitialReady = false;
            ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdDismissedFullScreenContent() {
                    afterInterstitial();
                }

                @Override
                public void onAdFailedToShowFullScreenContent(AdError error) {
                    afterInterstitial();
                }
            });
            ad.show(activity);
        });
    }

    @UsedByGodot
    public void showRewarded() {
        main.post(() -> {
            final Activity activity = getActivity();
            final RewardedAd ad = rewarded;
            if (ad == null || activity == null) {
                emitSignal("rewarded_finished", Boolean.FALSE);
                return;
            }
            rewarded = null;
            rewardedReady = false;
            rewardEarned = false;
            ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdDismissedFullScreenContent() {
                    afterRewarded();
                }

                @Override
                public void onAdFailedToShowFullScreenContent(AdError error) {
                    afterRewarded();
                }
            });
            ad.show(activity, rewardItem -> rewardEarned = true);
        });
    }

    @UsedByGodot
    public boolean isPrivacyOptionsRequired() {
        final Activity activity = getActivity();
        if (activity == null) {
            return false;
        }
        return UserMessagingPlatform.getConsentInformation(activity).getPrivacyOptionsRequirementStatus()
                == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED;
    }

    @UsedByGodot
    public void showPrivacyOptions() {
        final Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        activity.runOnUiThread(() -> UserMessagingPlatform.showPrivacyOptionsForm(activity, formError -> {
            if (formError != null) {
                Log.w(TAG, "Privacy options: " + formError.getMessage());
            }
        }));
    }

    // ------------------------------------------------------------------ consent + init

    private void requestConsent(final Activity activity) {
        final ConsentInformation info = UserMessagingPlatform.getConsentInformation(activity);
        ConsentRequestParameters params = new ConsentRequestParameters.Builder().build();
        info.requestConsentInfoUpdate(activity, params,
                () -> UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity, formError -> {
                    if (formError != null) {
                        Log.w(TAG, "Consent form: " + formError.getMessage());
                    }
                    if (info.canRequestAds()) {
                        startAds(activity);
                    }
                }),
                requestError -> {
                    Log.w(TAG, "Consent info: " + requestError.getMessage());
                    if (info.canRequestAds()) {
                        startAds(activity);
                    }
                });
        // Consent given in an earlier session: start right away.
        if (info.canRequestAds()) {
            startAds(activity);
        }
    }

    private void startAds(final Activity activity) {
        if (!adsStarted.compareAndSet(false, true)) {
            return;
        }
        new Thread(() -> MobileAds.initialize(activity, status -> main.post(() -> {
            emitSignal("initialized");
            createBanner(activity);
            loadInterstitial();
            loadRewarded();
        }))).start();
    }

    // ------------------------------------------------------------------ banner

    private void createBanner(Activity activity) {
        if (bannerId.isEmpty() || layout == null || bannerView != null) {
            return;
        }
        bannerView = new AdView(activity);
        bannerView.setAdSize(AdSize.BANNER);
        bannerView.setAdUnitId(bannerId);
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        layout.addView(bannerView, lp);
        bannerView.setVisibility(bannerVisible ? View.VISIBLE : View.GONE);
        bannerView.loadAd(new AdRequest.Builder().build());
    }

    private void setBannerVisible(final boolean visible) {
        main.post(() -> {
            bannerVisible = visible;
            if (bannerView != null) {
                bannerView.setVisibility(visible ? View.VISIBLE : View.GONE);
            }
        });
    }

    // ------------------------------------------------------------------ full-screen ads

    private void loadInterstitial() {
        final Activity activity = getActivity();
        if (activity == null || interstitialId.isEmpty()) {
            return;
        }
        InterstitialAd.load(activity, interstitialId, new AdRequest.Builder().build(),
                new InterstitialAdLoadCallback() {
                    @Override
                    public void onAdLoaded(InterstitialAd ad) {
                        interstitial = ad;
                        interstitialReady = true;
                    }

                    @Override
                    public void onAdFailedToLoad(LoadAdError error) {
                        interstitial = null;
                        interstitialReady = false;
                        emitSignal("ad_error", "interstitial: " + error.getMessage());
                        main.postDelayed(GodotAds.this::loadInterstitial, RETRY_MS);
                    }
                });
    }

    private void loadRewarded() {
        final Activity activity = getActivity();
        if (activity == null || rewardedId.isEmpty()) {
            return;
        }
        RewardedAd.load(activity, rewardedId, new AdRequest.Builder().build(),
                new RewardedAdLoadCallback() {
                    @Override
                    public void onAdLoaded(RewardedAd ad) {
                        rewarded = ad;
                        rewardedReady = true;
                    }

                    @Override
                    public void onAdFailedToLoad(LoadAdError error) {
                        rewarded = null;
                        rewardedReady = false;
                        emitSignal("ad_error", "rewarded: " + error.getMessage());
                        main.postDelayed(GodotAds.this::loadRewarded, RETRY_MS);
                    }
                });
    }

    private void afterInterstitial() {
        emitSignal("interstitial_closed");
        loadInterstitial();
    }

    private void afterRewarded() {
        emitSignal("rewarded_finished", rewardEarned ? Boolean.TRUE : Boolean.FALSE);
        loadRewarded();
    }

    // ------------------------------------------------------------------ lifecycle

    @Override
    public void onMainPause() {
        if (bannerView != null) {
            bannerView.pause();
        }
    }

    @Override
    public void onMainResume() {
        if (bannerView != null) {
            bannerView.resume();
        }
    }

    @Override
    public void onMainDestroy() {
        if (bannerView != null) {
            bannerView.destroy();
        }
    }
}
