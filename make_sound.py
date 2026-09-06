import numpy as np
import scipy.io.wavfile as wav
from scipy.signal import butter, sosfilt

# ============================================================
# Parameters
# ============================================================

sample_rate = 44100
duration = 10.0
num_samples = int(sample_rate * duration)

t = np.arange(num_samples) / sample_rate
rng = np.random.default_rng(42)

# Train passes the closest point at 5 seconds.
closest_time = 5.0


# ============================================================
# Utility functions
# ============================================================

def lowpass(signal, cutoff_hz, order=4):
    sos = butter(
        order,
        cutoff_hz,
        btype="lowpass",
        fs=sample_rate,
        output="sos"
    )
    return sosfilt(sos, signal)


def bandpass(signal, low_hz, high_hz, order=3):
    sos = butter(
        order,
        [low_hz, high_hz],
        btype="bandpass",
        fs=sample_rate,
        output="sos"
    )
    return sosfilt(sos, signal)


def add_sound(track, sound, start_time):
    start = int(start_time * sample_rate)
    end = min(start + len(sound), len(track))

    if start < len(track):
        track[start:end] += sound[:end-start]


# ============================================================
# 1. Train proximity / volume envelope
#
# 0-1 sec    approach
# 1-9 sec    beside window
# 9-10 sec   departure
# ============================================================

presence = np.ones(num_samples)

fade_samples = sample_rate

presence[:fade_samples] = np.linspace(
    0.20,
    1.0,
    fade_samples
)

presence[-fade_samples:] = np.linspace(
    1.0,
    0.15,
    fade_samples
)

# Slight additional boost around closest point.
presence *= (
    0.90
    + 0.10 * np.exp(
        -0.5 * ((t - closest_time) / 1.8) ** 2
    )
)


# ============================================================
# 2. Doppler shift
#
# Approaching train is slightly higher-pitched.
# After passing the listener it becomes slightly lower-pitched.
#
# This is intentionally subtle.
# ============================================================

doppler_amount = 0.045

doppler_ratio = (
    1.0
    - doppler_amount
    * np.tanh((t - closest_time) / 0.35)
)


def doppler_tone(base_frequency, amplitude, phase_offset=0):
    """
    Create a tone whose instantaneous frequency follows the
    Doppler curve.

    Integrating frequency into phase is important. Simply doing:

        sin(2*pi*frequency(t)*t)

    causes incorrect FM behavior.
    """

    instantaneous_frequency = base_frequency * doppler_ratio

    phase = (
        phase_offset
        + 2 * np.pi
        * np.cumsum(instantaneous_frequency)
        / sample_rate
    )

    return amplitude * np.sin(phase)


# ============================================================
# 3. Mechanical train rumble
#
# Most of the sound now comes from mechanical frequencies rather
# than broadband noise.
# ============================================================

mechanical = np.zeros(num_samples)

# Deep structure / wheels / traction machinery
mechanical += doppler_tone(34, 0.25)
mechanical += doppler_tone(49, 0.20, 1.1)
mechanical += doppler_tone(71, 0.14, 2.4)
mechanical += doppler_tone(103, 0.09, 0.8)
mechanical += doppler_tone(147, 0.055, 1.7)
mechanical += doppler_tone(218, 0.025, 0.3)

# Mechanical vibration shouldn't be perfectly constant.
slow_modulation = (
    0.90
    + 0.05 * np.sin(2 * np.pi * 0.65 * t)
    + 0.025 * np.sin(2 * np.pi * 1.73 * t)
)

mechanical *= slow_modulation


# ============================================================
# 4. Low frequency rolling texture
#
# Keep some noise, but restrict it strongly to low frequencies.
# This prevents the "white noise train" effect.
# ============================================================

noise = rng.normal(0, 1, num_samples)

deep_noise = lowpass(noise, 110)
deep_noise /= max(np.std(deep_noise), 0.00001)

rolling_noise = deep_noise * 0.045


# Add a quieter mid-frequency metal/rail texture.

noise2 = rng.normal(0, 1, num_samples)

rail_texture = bandpass(
    noise2,
    180,
    650
)

rail_texture /= max(np.std(rail_texture), 0.00001)

rail_texture *= 0.018


# ============================================================
# 5. Wheel rhythm
#
# Gives the rumble a repeating pulse as trucks/bogies pass.
# ============================================================

wheel_frequency = 5.4 * doppler_ratio

wheel_phase = (
    2 * np.pi
    * np.cumsum(wheel_frequency)
    / sample_rate
)

wheel_rhythm = (
    0.5
    + 0.5 * np.sin(wheel_phase)
)

# Sharpen the pulse.
wheel_rhythm = wheel_rhythm ** 5

rolling_noise *= (
    0.80
    + 0.45 * wheel_rhythm
)


# ============================================================
# 6. Rail joint / wheel clicks
# ============================================================

clicks = np.zeros(num_samples)

current_time = 1.05

while current_time < 8.95:

    current_time += rng.uniform(0.31, 0.39)

    # Two wheelsets make a "ka-DUNK" pair.
    pair_spacing = rng.uniform(0.055, 0.080)

    for offset, volume in [
        (0.0, 1.0),
        (pair_spacing, 0.72)
    ]:

        click_duration = 0.055
        click_t = np.arange(
            int(click_duration * sample_rate)
        ) / sample_rate

        fundamental = rng.uniform(120, 175)

        click = (
            0.45
            * np.exp(-70 * click_t)
            * np.sin(
                2 * np.pi
                * fundamental
                * click_t
            )
        )

        click += (
            0.18
            * np.exp(-130 * click_t)
            * np.sin(
                2 * np.pi
                * fundamental * 2.2
                * click_t
            )
        )

        # Very brief transient noise.
        click += (
            rng.normal(0, 1, len(click_t))
            * np.exp(-180 * click_t)
            * 0.025
        )

        add_sound(
            clicks,
            click * volume,
            current_time + offset
        )


# ============================================================
# 7. Heavy low-metal clanks
#
# These represent suspension, couplers, trucks, and structural
# impacts transmitting through an elevated rail structure.
# ============================================================

metal_clanks = np.zeros(num_samples)

clank_times = [
    1.82,
    2.95,
    4.15,
    5.32,
    6.55,
    7.48,
    8.28
]

for clank_time in clank_times:

    clank_duration = rng.uniform(0.25, 0.42)

    ct = np.arange(
        int(clank_duration * sample_rate)
    ) / sample_rate

    base_freq = rng.uniform(65, 88)

    # Heavy metallic impact.
    clank = (
        0.52
        * np.exp(-11 * ct)
        * np.sin(
            2 * np.pi
            * base_freq
            * ct
        )
    )

    # Ringing structure harmonic.
    clank += (
        0.24
        * np.exp(-17 * ct)
        * np.sin(
            2 * np.pi
            * base_freq * 1.55
            * ct
            + 0.7
        )
    )

    # Higher metal overtone.
    clank += (
        0.11
        * np.exp(-25 * ct)
        * np.sin(
            2 * np.pi
            * base_freq * 2.45
            * ct
            + 1.4
        )
    )

    # Very low "THUNK".
    clank += (
        0.20
        * np.exp(-30 * ct)
        * np.sin(
            2 * np.pi
            * rng.uniform(38, 48)
            * ct
        )
    )

    clank *= rng.uniform(0.65, 0.90)

    add_sound(
        metal_clanks,
        clank,
        clank_time
    )


# ============================================================
# 8. Wheel squeals
#
# More metallic and less like a pure sine wave.
# ============================================================

squeals = np.zeros(num_samples)

squeal_events = [
    (2.25, 0.52, 1450, 1750),
    (4.42, 0.37, 2300, 1900),
    (6.30, 0.61, 1600, 2050),
    (7.92, 0.41, 2450, 2150)
]

for (
    start_time,
    squeal_duration,
    start_frequency,
    end_frequency
) in squeal_events:

    count = int(
        squeal_duration
        * sample_rate
    )

    st = np.arange(count) / sample_rate

    frequency = np.linspace(
        start_frequency,
        end_frequency,
        count
    )

    # Add unstable friction oscillation.
    frequency += (
        55
        * np.sin(
            2 * np.pi
            * 11
            * st
        )
    )

    frequency += (
        20
        * np.sin(
            2 * np.pi
            * 23
            * st
        )
    )

    # Correct phase integration.
    phase = (
        2
        * np.pi
        * np.cumsum(frequency)
        / sample_rate
    )

    squeal = (
        np.sin(phase)
        + 0.30 * np.sin(2.03 * phase)
        + 0.12 * np.sin(3.17 * phase)
    )

    squeal_envelope = (
        np.sin(
            np.linspace(
                0,
                np.pi,
                count
            )
        ) ** 0.65
    )

    squeal *= squeal_envelope * rng.uniform(
        0.035,
        0.060
    )

    add_sound(
        squeals,
        squeal,
        start_time
    )


# ============================================================
# 9. Assemble mono train
# ============================================================

train = (
    mechanical
    + rolling_noise
    + rail_texture
    + clicks
    + metal_clanks
    + squeals
)

train *= presence


# ============================================================
# 10. Simulate listening through a window
#
# Cutting some high frequencies helps make it sound like the
# elevated train is outside rather than inside the room.
# ============================================================

outside_filtered = lowpass(
    train,
    5200
)

train = (
    0.70 * outside_filtered
    + 0.30 * train
)


# ============================================================
# 11. Stereo pass
#
# Train enters toward the left, moves across the window, then
# exits toward the right.
# ============================================================

pan = np.clip(
    (t - 0.6) / 8.8,
    0,
    1
)

left_pan = np.cos(
    pan * np.pi / 2
)

right_pan = np.sin(
    pan * np.pi / 2
)

# Don't make either side completely disappear.
left_gain = (
    0.65
    + 0.35 * left_pan
)

right_gain = (
    0.65
    + 0.35 * right_pan
)

left = train * left_gain
right = train * right_gain


# ============================================================
# 12. Small exterior reflection
#
# Simulates reflections between nearby buildings / elevated
# structure without making the sound obviously reverberant.
# ============================================================

delay_samples = int(
    0.032
    * sample_rate
)

left_delayed = np.zeros_like(left)
right_delayed = np.zeros_like(right)

left_delayed[delay_samples:] = (
    right[:-delay_samples]
)

right_delayed[delay_samples:] = (
    left[:-delay_samples]
)

left += left_delayed * 0.08
right += right_delayed * 0.08


# ============================================================
# 13. Normalize
# ============================================================

stereo = np.column_stack(
    (left, right)
)

peak = np.max(
    np.abs(stereo)
)

if peak > 0:
    stereo /= peak

# Leave some headroom.
stereo *= 0.92

audio_int16 = (
    stereo * 32767
).astype(np.int16)


# ============================================================
# Save
# ============================================================

output_filename = "elevated_train_window_improved.wav"

wav.write(
    output_filename,
    sample_rate,
    audio_int16
)

print(
    f"Saved '{output_filename}'"
)