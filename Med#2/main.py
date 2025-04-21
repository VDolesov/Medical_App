import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sqlalchemy import create_engine
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score
from imblearn.over_sampling import SMOTE

# Подключение к базе данных
engine = create_engine("postgresql://postgres:****@localhost:5432/medical_data")
df = pd.read_sql("SELECT * FROM newtable", con=engine)
df.columns = df.columns.str.lower()

# Определение осложнений
col = [c for c in df.columns if "осложнения" in c.lower()][0]
df["complications"] = df[col].apply(lambda x: 1 if isinstance(x, str) and x.strip() != "" else 0)

print("Распределение осложнений:")
print(df["complications"].value_counts())

# Подготовка числовых признаков
df_numeric = df.select_dtypes(include=["float64", "int64"]).copy()
df_numeric["complications"] = df["complications"]
df_numeric = df_numeric.fillna(df_numeric.median())

# Расчёт корреляции
correlation = df_numeric.corr()["complications"].drop("complications").sort_values(ascending=False)
top_10_corr = correlation.head(10)
print("\nТоп-10 признаков, связанных с осложнениями:")
print(top_10_corr)

# График корреляции
plt.figure(figsize=(10, 6))
sns.barplot(y=top_10_corr.index, x=top_10_corr.values)
plt.xlabel("Коэффициент корреляции")
plt.ylabel("Признак")
plt.title("Связь признаков с осложнениями")
plt.tight_layout()
plt.savefig("correlation_with_complications.png")
print("График сохранён: correlation_with_complications.png")

# Обучение модели на исходных данных
features = top_10_corr.index.tolist()
X = df_numeric[features]
y = df_numeric["complications"]
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, stratify=y, random_state=42)
model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)
y_pred = model.predict(X_test)

print("\nМетрики модели (без балансировки):")
print(f"Точность: {accuracy_score(y_test, y_pred):.4f}")
print(classification_report(y_test, y_pred))

# Балансировка классов (SMOTE)
smote = SMOTE(random_state=42)
X_resampled, y_resampled = smote.fit_resample(X, y)
X_train, X_test, y_train, y_test = train_test_split(X_resampled, y_resampled, test_size=0.2, random_state=42)

model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)
y_pred = model.predict(X_test)

print("\nМетрики модели (после SMOTE):")
print(f"Точность: {accuracy_score(y_test, y_pred):.4f}")
print(classification_report(y_test, y_pred))

# Визуализация вероятностей по ключевым признакам
X_test_copy = X_test.copy()
X_test_copy["probability"] = model.predict_proba(X_test)[:, 1]

for feature in features[:3]:
    plt.figure(figsize=(8, 5))
    sns.regplot(x=feature, y="probability", data=X_test_copy, lowess=True,
                scatter_kws={"s": 10}, line_kws={"color": "red"})
    plt.title(f"Вероятность осложнений от признака: {feature}")
    plt.xlabel(feature)
    plt.ylabel("Вероятность")
    fname = f"plot_{feature}.png".replace(" ", "_").replace("/", "_")
    plt.tight_layout()
    plt.savefig(fname)
    print(f"График сохранён: {fname}")
