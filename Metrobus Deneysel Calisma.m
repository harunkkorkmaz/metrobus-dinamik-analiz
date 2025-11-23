% --- MERCEDES CONNECTO G METROBÜS HATTI SİMÜLASYONU ---
% Senaryo: Beylikdüzü -> Söğütlüçeşme (Full Yolcu + Bozuk Yol)
clear; clc; close all;

%% 1. ARAÇ VE YOLCU PARAMETRELERİ (Mercedes Connecto G)
m_bos_on = 11000;    % Ön kısım boş kütle (kg)
m_bos_arka = 7000;   % Arka kısım (dorse) boş kütle (kg)

% Yolcu Yüklemesi (Full + Valizler)
yolcu_sayisi = 160;  % Tıka basa dolu
ortalama_kilo = 75;  % İnsan + Valiz ortalaması
toplam_yolcu_yuku = yolcu_sayisi * ortalama_kilo;

% Yükün dağılımı (%60 ön, %40 arka varsayımı)
m_on = m_bos_on + (toplam_yolcu_yuku * 0.60);
m_arka = m_bos_arka + (toplam_yolcu_yuku * 0.40);
m_toplam = m_on + m_arka;

fprintf('Simülasyon Başlıyor...\n');
fprintf('Araç: Mercedes Connecto G\n');
fprintf('Toplam Ağırlık: %.1f Ton\n', m_toplam/1000);
fprintf('Güzergah: Beylikdüzü -> Söğütlüçeşme\n');
fprintf('--------------------------------------\n');

%% 2. HAT VE YOL PARAMETRELERİ
durak_sayisi = 44; % Metrobüs hattı durak sayısı
dt = 0.5;          % Zaman adımı (sn) - Simülasyon hassasiyeti

% Verileri Saklamak İçin Diziler
zaman_log = [];
hiz_log = [];
koruk_kuvveti_log = []; % Newton
yol_bozuklugu_log = [];
egim_log = [];
mesafe_log = [];

toplam_mesafe = 0;
gecen_sure = 0;
anlik_hiz = 0; % m/s

%% 3. SİMÜLASYON DÖNGÜSÜ (DURAK DURAK İLERLEME)

for durak = 1:durak_sayisi
    % Her durak arası mesafe ve koşullar rastgele ama mantıklı sınırlar içinde
    mesafe_hedef = 800 + randn()*200; % Ortalama 1000m durak arası
    if mesafe_hedef < 400, mesafe_hedef = 400; end
    
    % Yol Kalitesi (1: Kaymak Asfalt, 5: Mayın Tarlası)
    % Metrobüs yolu genelde bozuktur, kaliteyi düşük tutuyoruz.
    yol_kalitesi = 3 + rand()*2; 
    
    % Eğim Durumu (Rampa çıkış/iniş) - Derece cinsinden
    % -5 (iniş) ile +5 (yokuş) arası
    egim = (rand() - 0.5) * 10; 
    
    % Viraj Sertliği (Körük kasılması için)
    viraj_faktoru = rand(); 
    
    durak_ici_mesafe = 0;
    faz = 1; % 1: Hızlanma, 2: Sabit Hız, 3: Frenleme, 4: Duraklama
    
    while faz < 5
        gecen_sure = gecen_sure + dt;
        
        % --- SÜRÜŞ FAZLARI ---
        if faz == 1 % Hızlanma (Gaz kökleme)
            ivme = 1.2; % m/s^2 (Dolu araç yavaş hızlanır)
            if anlik_hiz > 13, faz = 2; end % 50 km/h hıza ulaşınca sabitle
            
        elseif faz == 2 % Seyir (Cruise)
            ivme = 0;
            % Yoldaki virajlara ve trafiğe göre hafif hız değişimleri
            ivme = ivme + (rand()-0.5)*0.2; 
            if durak_ici_mesafe > (mesafe_hedef - 150), faz = 3; end % Durağa 150m kala fren
            
        elseif faz == 3 % Frenleme (Sert giriş)
            ivme = -1.5; % m/s^2
            if anlik_hiz <= 0.1
                anlik_hiz = 0;
                ivme = 0;
                faz = 4;
                bekleme_suresi = 15; % Yolcu indirme bindirme süresi
            end
            
        elseif faz == 4 % Durakta Bekleme & Kneeling (Yana yatma)
            ivme = 0;
            bekleme_suresi = bekleme_suresi - dt;
            if bekleme_suresi <= 0, faz = 5; end % Hareket et
        end
        
        % Hız ve Konum İntegrasyonu
        anlik_hiz = anlik_hiz + ivme * dt;
        if anlik_hiz < 0, anlik_hiz = 0; end % Geri gitme yok
        
        ds = anlik_hiz * dt;
        durak_ici_mesafe = durak_ici_mesafe + ds;
        toplam_mesafe = toplam_mesafe + ds;
        
        %% 4. KÖRÜK (ARTICULATION) KUVVET HESABI
        % Bu kısım projenin kalbi.
        % Körükteki kuvvet = (Arka Kütle * İvme) + (Yol Dirençleri)
        
        % A. Boyuna Kuvvet (Çeki/Bası)
        % F = m*a formülü, ama arka dorse için.
        % Rampa yukarı çıkarken motor körüğü çeker (Pozitif)
        % Fren yaparken arka dorse önü iter (Negatif - Bası)
        g = 9.81;
        F_atalet = m_arka * ivme;
        F_yercekimi = m_arka * g * sind(egim); % Yokuş etkisi
        
        F_longitudinal = F_atalet + F_yercekimi;
        
        % B. Dikey Kuvvet (Yol Bozukluğu - Mayın Tarlası Etkisi)
        % Rastgele şoklar (Bump)
        % Yol kalitesi arttıkça genlik artar.
        if anlik_hiz > 1
            vibrasyon = randn() * yol_kalitesi * 1500; % Newton cinsinden anlık darbe
        else
            vibrasyon = 0; % Dururken titreşim az (Sadece motor rölantisi)
            if faz == 4, vibrasyon = 500; end % Kapı açılma/Kneeling sarsıntısı
        end
        F_vertical = (m_arka * g) + vibrasyon;
        
        % C. Yanal Kuvvet (Virajlar ve Sert Şerit Değiştirme)
        % Metrobüs şoförleri bazen sert girer.
        merkezkac = (m_arka * anlik_hiz^2 / 50) * viraj_faktoru; % R=50m viraj yarıçapı varsayımı
        F_lateral = merkezkac;
        
        % BİLEŞKE KÖRÜK STRESİ (Von Mises benzeri bir yaklaşım)
        % Körüğün maruz kaldığı toplam zorlanma
        F_total_joint = sqrt(F_longitudinal^2 + F_vertical^2 + F_lateral^2);
        
        % --- LOGLAMA ---
        zaman_log(end+1) = gecen_sure;
        hiz_log(end+1) = anlik_hiz * 3.6; % km/h çevrimi
        koruk_kuvveti_log(end+1) = F_total_joint;
        yol_bozuklugu_log(end+1) = yol_kalitesi;
        egim_log(end+1) = egim;
        mesafe_log(end+1) = toplam_mesafe/1000; % km
    end
    
    % İlerleme Durumu
    if mod(durak, 5) == 0
        fprintf('Durak %d/%d tamamlandı. (%.1f km)\n', durak, durak_sayisi, toplam_mesafe/1000);
    end
end

%% 5. SONUÇLAR VE GRAFİK ANALİZİ
fprintf('Simülasyon Bitti. Analiz Çiziliyor...\n');

figure('Color', 'white', 'Name', 'Metrobüs Dinamik Analizi', 'Position', [50 50 1200 700]);

% 1. Hız Profili
subplot(3,1,1);
plot(mesafe_log, hiz_log, 'b', 'LineWidth', 1);
title(['Hız Profili (Beylikdüzü - Söğütlüçeşme) - Toplam Yük: ' num2str(m_toplam/1000) ' Ton']);
ylabel('Hız (km/h)');
grid on;
xline(10, '--k', 'Avcılar'); % Temsili durak yerleri
xline(25, '--k', 'Cevizlibağ');
xline(40, '--k', 'Mecidiyeköy');

% 2. Körük Üzerindeki Stres (Kuvvet)
subplot(3,1,2);
plot(mesafe_log, koruk_kuvveti_log/1000, 'r'); % kN cinsinden
title('Körük (Articulation) Üzerindeki Anlık Bileşke Kuvvetler');
ylabel('Kuvvet (kN)');
grid on;
yline(150, 'r--', 'Kritik Sınır (Hasar Riski)'); % Temsili bir sınır

% 3. Yol Profili ve Eğim
subplot(3,1,3);
area(mesafe_log, egim_log, 'FaceColor', [0.8 0.8 0.8]);
hold on;
plot(mesafe_log, egim_log, 'k');
title('Yol Eğimi (Rampalar ve İnişler)');
xlabel('Mesafe (km)');
ylabel('Eğim (Derece)');
grid on;
ylim([-10 10]);

% İstatistiksel Rapor
max_stress = max(koruk_kuvveti_log);
avg_stress = mean(koruk_kuvveti_log);

msgbox({
    ['Toplam Mesafe: ' num2str(toplam_mesafe/1000, '%.1f') ' km'];
    ['Maksimum Körük Kuvveti: ' num2str(max_stress/1000, '%.1f') ' kN'];
    ['Yolcu + Araç Ağırlığı: ' num2str(m_toplam/1000) ' Ton'];
    'Sonuç: Araç 44 durak boyunca ağır yük ve bozuk yol';
    'nedeniyle körük sisteminde yüksek yorulma riski taşıyor.';
}, 'Simülasyon Raporu');