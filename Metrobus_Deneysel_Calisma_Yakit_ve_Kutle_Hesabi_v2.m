% --- MERCEDES METROBÜS DEĞİŞKEN KÜTLELİ SİMÜLASYON ---
% Özellik: Yakıt Tüketimi + Yolcu İniş/Biniş Simülasyonu
clear; clc; close all;

%% 1. BAŞLANGIÇ PARAMETRELERİ
% Yakıt Sistemi (Dizel)
depo_hacmi_L = 350;         % 350 Litre depo
yakit_yogunluk = 0.835;     % Dizel yoğunluğu (kg/L)
mevcut_yakit_kg = depo_hacmi_L * yakit_yogunluk; % ~292 kg yakıt

% Araç ve Yolcu
m_bos_arac = 18000;         % 18 Ton (Körüklü boş ağırlık)
yolcu_sayisi = 200;         % İlk durakta binen (Full)
ort_yolcu_kg = 75;

% Motor Verileri (Mercedes OM457 benzeri)
bsfc = 210;                 % Brake Specific Fuel Consumption (g/kWh)
% (Her 1 kWh güç üretmek için motorun yaktığı gram mazot)

%% 2. SİMÜLASYON HAZIRLIĞI (PRE-ALLOCATION)
dt = 0.5;
tahmini_adim = 200000;
toplam_mesafe = 52000; % 52 km

% RAM Dostu Diziler
log_mesafe = zeros(1, tahmini_adim);
log_hiz = zeros(1, tahmini_adim);
log_kuttle = zeros(1, tahmini_adim); % Toplam ağırlık kaydı
log_yakit = zeros(1, tahmini_adim);  % Depoda kalan yakıt
log_anlik_tuketim = zeros(1, tahmini_adim); % Litre/100km hesabı için

%% 3. HAREKET DÖNGÜSÜ
x = 0; v = 0; t = 0; i = 1;
durak_sayaci = 0;
son_durak_konumu = 0;

fprintf('Motor Çalıştı. Depo: %.1f Litre. Yolcu: %d\n', depo_hacmi_L, yolcu_sayisi);

while x < toplam_mesafe && i < tahmini_adim
    t = t + dt;
    
    % --- A. Kütle Güncellemesi (Her saniye değişiyor!) ---
    m_yakit = mevcut_yakit_kg;
    m_yolcu = yolcu_sayisi * ort_yolcu_kg;
    m_toplam = m_bos_arac + m_yolcu + m_yakit;
    
    % --- B. Durak ve Yolcu Senaryosu ---
    % Her 1 km'de bir durak var varsayalım
    if x - son_durak_konumu > 1000 
        % Durağa geldik: Yolcu değişimi yap
        inen = randi([10, 30]); % 10-30 kişi iner
        binen = randi([10, 40]); % 10-40 kişi biner
        
        yolcu_sayisi = yolcu_sayisi - inen + binen;
        if yolcu_sayisi > 280, yolcu_sayisi = 280; end % Kapasite sınırı
        if yolcu_sayisi < 0, yolcu_sayisi = 0; end
        
        son_durak_konumu = x; % Sonraki durak için sayacı sıfırla
        v = 0; % Durduk
        % Durakta rölanti yakıt tüketimi (0.5 sn için az bir miktar)
        mevcut_yakit_kg = mevcut_yakit_kg - 0.0002; 
    end
    
    % --- C. Sürüş Fiziği ---
    hedef_hiz = 80/3.6;
    if v < hedef_hiz
        a_ist = 0.8; % Gaz (Hızlanma)
    else
        a_ist = 0;   % Sabit hız (Sadece direnci yen)
    end
    
    % Direnç Kuvvetleri
    F_direnc = 2000 + (0.9 * v^2); % Hava + Tekerlek
    F_motor = m_toplam * a_ist + F_direnc;
    
    % --- D. Yakıt Tüketimi Hesabı (Motor Haritası) ---
    Guc_kW = (F_motor * v) / 1000; % kW cinsinden güç
    
    if Guc_kW > 0
        % Formül: Tüketim (kg) = (Güç * BSFC * zaman) / (Verim faktörleri)
        % Birim dönüşümleri: g -> kg, saat -> saniye
        yakilan_yakit_kg = (Guc_kW * bsfc * (dt/3600)) / 1000;
        
        mevcut_yakit_kg = mevcut_yakit_kg - yakilan_yakit_kg;
        if mevcut_yakit_kg < 0, mevcut_yakit_kg =