# Object Tracking: Kalman Filters and Nearest Neighbor Matching

## Kalman Filter

A Kalman filter is an algorithm that uses a series of measurements observed over time to estimate unknown variables with more precision than a single measurement alone.

### Key Concepts

1. **Prediction**: Estimate the future state based on previous knowledge.
2. **Measurement**: Observe the actual state (with some error).
3. **Update**: Combine prediction and measurement for a better estimate.

### In Object Tracking

- Predicts object's future position based on its current state and motion model.
- Incorporates new measurements to refine predictions.
- Handles noise in both predictions and measurements.

### Advantages

- Handles uncertainty in both the prediction and measurement.
- Works well for linear systems with Gaussian noise.
- Provides continuous tracking even with occasional missing data.

## Nearest Neighbor Matching

### How It Works

1. Start with a list of previously tracked objects.
2. For each new detection, find the closest match among the tracked objects.
3. Associate the detection with the closest tracked object.

### "Closest" Can Mean

- Physically nearest in position
- Most similar in appearance
- Nearest to predicted position (if using predictive methods like Kalman filter)

### Challenges

- Confusion when objects are close together
- Mismatches when objects disappear temporarily
- Issues with new objects entering the scene

### Improvements

- Set a maximum matching distance
- Use additional features (size, color, etc.) for matching
- Combine with predictive methods for more accurate associations

## Combining Kalman Filter and Nearest Neighbor?

1. Use Kalman filter to predict next position of tracked objects.
2. Apply nearest neighbor matching between predictions and new detections.
3. Update Kalman filter estimates with matched detections.
4. For unmatched objects, rely on Kalman predictions and seek matches in future frames.
