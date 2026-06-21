# BEFORE you run this, make sure the following is installed in your environment:

# numpy
# pandas
# scikit-learn
# matplotlib

# Use this command to install the required libraries:
# pip install numpy pandas scikit-learn matplotlib

# Code is not mine, it's from here: https://medium.com/@aleksej.gudkov/artificial-intelligence-python-code-example-a-beginners-guide-04f3b8291c43

# Import libraries
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error
import matplotlib.pyplot as plt

# Create a simple dataset
data = {
    "Size (sq ft)": [1500, 2000, 2500, 3000, 3500],
    "Bedrooms": [3, 4, 4, 5, 5],
    "Age (years)": [10, 15, 20, 25, 30],
    "Price (USD)": [300000, 400000, 500000, 600000, 700000]
}

# Convert the dataset into a pandas DataFrame
df = pd.DataFrame(data)
print("Dataset:")
print(df)


X = df[["Size (sq ft)", "Bedrooms", "Age (years)"]]
y = df["Price (USD)"]

# Split the data into training and testing sets
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
print("Training Features:")
print(X_train)
print("Testing Features:")
print(X_test)

# Initialize the Linear Regression model
model = LinearRegression()

# Train the model
model.fit(X_train, y_train)
print("Model Trained Successfully!")


# Make predictions
predictions = model.predict(X_test)

print("Predicted Prices:")
print(predictions)
print("Actual Prices:")
print(y_test.values)

# Calculate Mean Squared Error
mse = mean_squared_error(y_test, predictions)
print(f"Mean Squared Error: {mse:.2f}")

# Plot predictions vs actual values
plt.scatter(y_test, predictions)
plt.plot([min(y_test), max(y_test)], [min(y_test), max(y_test)], color='red', linewidth=2)
plt.xlabel("Actual Prices")
plt.ylabel("Predicted Prices")
plt.title("Actual vs Predicted Prices")
plt.show()