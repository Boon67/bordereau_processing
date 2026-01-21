#!/usr/bin/env python3
"""
Sample Data Generator for Bordereau Processing Pipeline
========================================================

Generates realistic sample data for all layers:
- Bronze: Raw claims, members, providers
- Silver: Transformed and validated data
- Gold: Analytics-ready aggregations
- Member Journeys: Healthcare journey tracking

Usage:
    python generate_sample_data.py --output-dir ./output --num-claims 1000
"""

import argparse
import csv
import random
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Dict, Any
import json

# Configuration
TPAS = [
    {"code": "provider_a", "name": "Provider A Healthcare"},
    {"code": "provider_b", "name": "Provider B Insurance"},
    {"code": "provider_c", "name": "Provider C Medical"},
    {"code": "provider_d", "name": "Provider D Dental"},
    {"code": "provider_e", "name": "Provider E Pharmacy"},
]

CLAIM_TYPES = ["MEDICAL", "DENTAL", "PHARMACY"]

MEDICAL_SPECIALTIES = [
    "Family Medicine", "Internal Medicine", "Cardiology", "Orthopedics",
    "Pediatrics", "OB/GYN", "Dermatology", "Psychiatry", "Emergency Medicine",
    "Radiology", "Anesthesiology", "Surgery"
]

DENTAL_SPECIALTIES = [
    "General Dentistry", "Orthodontics", "Periodontics", "Endodontics",
    "Oral Surgery", "Prosthodontics"
]

PHARMACY_TYPES = [
    "Retail Pharmacy", "Mail Order Pharmacy", "Specialty Pharmacy",
    "Hospital Pharmacy"
]

DIAGNOSIS_CODES = [
    "E11.9", "I10", "J45.909", "M79.3", "K21.9", "F41.9", "M54.5",
    "E78.5", "Z23", "R51", "J06.9", "N39.0", "K59.00", "R10.9"
]

PROCEDURE_CODES = [
    "99213", "99214", "99215", "99203", "99204", "80053", "85025",
    "93000", "71020", "99285", "99284", "45378", "29881"
]

DRUG_NAMES = [
    "Lisinopril", "Metformin", "Amlodipine", "Atorvastatin", "Metoprolol",
    "Omeprazole", "Albuterol", "Levothyroxine", "Gabapentin", "Sertraline",
    "Losartan", "Simvastatin", "Prednisone", "Amoxicillin", "Hydrochlorothiazide"
]

STATES = [
    "CA", "TX", "FL", "NY", "PA", "IL", "OH", "GA", "NC", "MI",
    "NJ", "VA", "WA", "AZ", "MA", "TN", "IN", "MO", "MD", "WI"
]

FIRST_NAMES = [
    "James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
    "William", "Elizabeth", "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
    "Thomas", "Sarah", "Charles", "Karen", "Christopher", "Nancy", "Daniel", "Lisa"
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
    "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
    "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Thompson", "White"
]

JOURNEY_TYPES = [
    "PREVENTIVE_CARE",
    "CHRONIC_DISEASE_MANAGEMENT",
    "ACUTE_EPISODE",
    "SURGICAL_PROCEDURE",
    "MATERNITY",
    "MENTAL_HEALTH",
    "EMERGENCY_CARE"
]

JOURNEY_STAGES = [
    "INITIAL_VISIT",
    "DIAGNOSIS",
    "TREATMENT_PLANNING",
    "ACTIVE_TREATMENT",
    "FOLLOW_UP",
    "MAINTENANCE",
    "COMPLETED",
    "DISCONTINUED"
]


class SampleDataGenerator:
    """Generate sample data for the Bordereau pipeline"""
    
    def __init__(self, output_dir: Path, num_claims: int = 1000):
        self.output_dir = output_dir
        self.num_claims = num_claims
        self.members: List[Dict] = []
        self.providers: List[Dict] = []
        self.claims: List[Dict] = []
        self.journeys: List[Dict] = []
        self.journey_events: List[Dict] = []
        
        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
    def generate_all(self):
        """Generate all sample data"""
        print("🎲 Generating sample data...")
        print(f"   Output directory: {self.output_dir}")
        print(f"   Number of claims: {self.num_claims}")
        
        # Generate in order of dependencies
        self.generate_members()
        self.generate_providers()
        self.generate_claims()
        self.generate_journeys()
        self.generate_journey_events()
        
        # Write to CSV files
        self.write_csv_files()
        
        # Generate summary
        self.print_summary()
        
    def generate_members(self):
        """Generate member data"""
        print("\n👥 Generating members...")
        num_members = max(100, self.num_claims // 10)  # ~10 claims per member
        
        for i in range(num_members):
            tpa = random.choice(TPAS)
            dob = datetime.now() - timedelta(days=random.randint(365*18, 365*80))
            enrollment_date = datetime.now() - timedelta(days=random.randint(30, 365*5))
            
            member = {
                "member_id": f"MEM{i+1:06d}",
                "tpa": tpa["code"],
                "first_name": random.choice(FIRST_NAMES),
                "last_name": random.choice(LAST_NAMES),
                "date_of_birth": dob.strftime("%Y-%m-%d"),
                "gender": random.choice(["M", "F", "O"]),
                "state": random.choice(STATES),
                "zip_code": f"{random.randint(10000, 99999)}",
                "enrollment_date": enrollment_date.strftime("%Y-%m-%d"),
                "is_active": random.choice([True, True, True, False]),  # 75% active
                "created_at": datetime.now().isoformat()
            }
            self.members.append(member)
            
        print(f"   ✓ Generated {len(self.members)} members")
        
    def generate_providers(self):
        """Generate provider data"""
        print("\n🏥 Generating providers...")
        num_providers = max(50, self.num_claims // 20)  # ~20 claims per provider
        
        for i in range(num_providers):
            tpa = random.choice(TPAS)
            claim_type = random.choice(CLAIM_TYPES)
            
            if claim_type == "MEDICAL":
                specialty = random.choice(MEDICAL_SPECIALTIES)
                provider_type = random.choice(["Individual", "Facility"])
            elif claim_type == "DENTAL":
                specialty = random.choice(DENTAL_SPECIALTIES)
                provider_type = "Individual"
            else:  # PHARMACY
                specialty = random.choice(PHARMACY_TYPES)
                provider_type = "Facility"
            
            provider = {
                "provider_id": f"PRV{i+1:06d}",
                "tpa": tpa["code"],
                "provider_name": f"{random.choice(LAST_NAMES)} {provider_type}",
                "provider_type": provider_type,
                "specialty": specialty,
                "claim_type": claim_type,
                "npi": f"{random.randint(1000000000, 9999999999)}",
                "tax_id": f"{random.randint(10, 99)}-{random.randint(1000000, 9999999)}",
                "address": f"{random.randint(100, 9999)} Main St",
                "city": "Sample City",
                "state": random.choice(STATES),
                "zip_code": f"{random.randint(10000, 99999)}",
                "is_active": random.choice([True, True, True, False]),  # 75% active
                "created_at": datetime.now().isoformat()
            }
            self.providers.append(provider)
            
        print(f"   ✓ Generated {len(self.providers)} providers")
        
    def generate_claims(self):
        """Generate claims data"""
        print("\n📋 Generating claims...")
        
        for i in range(self.num_claims):
            member = random.choice(self.members)
            provider = random.choice([p for p in self.providers if p["tpa"] == member["tpa"]])
            claim_type = provider["claim_type"]
            
            service_date = datetime.now() - timedelta(days=random.randint(1, 365))
            received_date = service_date + timedelta(days=random.randint(1, 30))
            
            # Generate amounts
            if claim_type == "MEDICAL":
                billed = random.uniform(100, 5000)
            elif claim_type == "DENTAL":
                billed = random.uniform(50, 2000)
            else:  # PHARMACY
                billed = random.uniform(10, 500)
            
            allowed = billed * random.uniform(0.5, 0.9)
            paid = allowed * random.uniform(0.8, 1.0)
            member_responsibility = allowed - paid
            
            claim = {
                "claim_id": f"CLM{i+1:08d}",
                "tpa": member["tpa"],
                "member_id": member["member_id"],
                "provider_id": provider["provider_id"],
                "claim_type": claim_type,
                "service_date": service_date.strftime("%Y-%m-%d"),
                "received_date": received_date.strftime("%Y-%m-%d"),
                "diagnosis_code": random.choice(DIAGNOSIS_CODES),
                "procedure_code": random.choice(PROCEDURE_CODES) if claim_type != "PHARMACY" else "",
                "drug_name": random.choice(DRUG_NAMES) if claim_type == "PHARMACY" else "",
                "billed_amount": round(billed, 2),
                "allowed_amount": round(allowed, 2),
                "paid_amount": round(paid, 2),
                "member_responsibility": round(member_responsibility, 2),
                "claim_status": random.choice(["PAID", "PAID", "PAID", "DENIED", "PENDING"]),
                "denial_reason": "Insufficient documentation" if random.random() < 0.1 else "",
                "created_at": datetime.now().isoformat()
            }
            self.claims.append(claim)
            
        print(f"   ✓ Generated {len(self.claims)} claims")
        
    def generate_journeys(self):
        """Generate member healthcare journeys"""
        print("\n🗺️  Generating member journeys...")
        
        # Create 1-3 journeys per member
        for member in self.members:
            num_journeys = random.randint(1, 3)
            
            for j in range(num_journeys):
                journey_type = random.choice(JOURNEY_TYPES)
                start_date = datetime.now() - timedelta(days=random.randint(30, 730))
                
                # Some journeys are completed, some ongoing
                is_completed = random.choice([True, True, False])
                if is_completed:
                    end_date = start_date + timedelta(days=random.randint(30, 365))
                    current_stage = "COMPLETED"
                else:
                    end_date = None
                    current_stage = random.choice([
                        "ACTIVE_TREATMENT", "FOLLOW_UP", "MAINTENANCE"
                    ])
                
                # Calculate metrics
                related_claims = [c for c in self.claims if c["member_id"] == member["member_id"]]
                total_cost = sum(c["paid_amount"] for c in related_claims[:random.randint(1, 10)])
                num_visits = random.randint(1, 20)
                
                journey = {
                    "journey_id": f"JRN{uuid.uuid4().hex[:12].upper()}",
                    "member_id": member["member_id"],
                    "tpa": member["tpa"],
                    "journey_type": journey_type,
                    "start_date": start_date.strftime("%Y-%m-%d"),
                    "end_date": end_date.strftime("%Y-%m-%d") if end_date else "",
                    "current_stage": current_stage,
                    "primary_diagnosis": random.choice(DIAGNOSIS_CODES),
                    "primary_provider_id": random.choice([p["provider_id"] for p in self.providers if p["tpa"] == member["tpa"]]),
                    "total_cost": round(total_cost, 2),
                    "num_visits": num_visits,
                    "num_providers": random.randint(1, 5),
                    "is_active": not is_completed,
                    "quality_score": round(random.uniform(3.0, 5.0), 2) if is_completed else None,
                    "patient_satisfaction": round(random.uniform(3.0, 5.0), 2) if is_completed else None,
                    "created_at": datetime.now().isoformat(),
                    "updated_at": datetime.now().isoformat()
                }
                self.journeys.append(journey)
                
        print(f"   ✓ Generated {len(self.journeys)} member journeys")
        
    def generate_journey_events(self):
        """Generate events within each journey"""
        print("\n📅 Generating journey events...")
        
        for journey in self.journeys:
            num_events = random.randint(2, 10)
            start_date = datetime.strptime(journey["start_date"], "%Y-%m-%d")
            
            for e in range(num_events):
                event_date = start_date + timedelta(days=random.randint(0, 365))
                event_type = random.choice([
                    "APPOINTMENT", "PROCEDURE", "LAB_TEST", "PRESCRIPTION",
                    "HOSPITAL_ADMISSION", "HOSPITAL_DISCHARGE", "FOLLOW_UP"
                ])
                
                event = {
                    "event_id": f"EVT{uuid.uuid4().hex[:12].upper()}",
                    "journey_id": journey["journey_id"],
                    "event_date": event_date.strftime("%Y-%m-%d"),
                    "event_type": event_type,
                    "event_stage": random.choice(JOURNEY_STAGES),
                    "provider_id": journey["primary_provider_id"],
                    "diagnosis_code": journey["primary_diagnosis"],
                    "procedure_code": random.choice(PROCEDURE_CODES) if event_type in ["PROCEDURE", "LAB_TEST"] else "",
                    "cost": round(random.uniform(50, 2000), 2),
                    "notes": f"Sample {event_type.lower().replace('_', ' ')} event",
                    "created_at": datetime.now().isoformat()
                }
                self.journey_events.append(event)
                
        print(f"   ✓ Generated {len(self.journey_events)} journey events")
        
    def write_csv_files(self):
        """Write all data to CSV files"""
        print("\n💾 Writing CSV files...")
        
        # Members
        self._write_csv("members.csv", self.members)
        
        # Providers
        self._write_csv("providers.csv", self.providers)
        
        # Claims
        self._write_csv("claims.csv", self.claims)
        
        # Journeys
        self._write_csv("member_journeys.csv", self.journeys)
        
        # Journey Events
        self._write_csv("journey_events.csv", self.journey_events)
        
        # TPAs (for reference)
        self._write_csv("tpas.csv", [
            {"tpa_code": tpa["code"], "tpa_name": tpa["name"]}
            for tpa in TPAS
        ])
        
        print(f"   ✓ All files written to {self.output_dir}")
        
    def _write_csv(self, filename: str, data: List[Dict]):
        """Write data to CSV file"""
        if not data:
            return
            
        filepath = self.output_dir / filename
        with open(filepath, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=data[0].keys())
            writer.writeheader()
            writer.writerows(data)
        print(f"      • {filename}: {len(data)} records")
        
    def print_summary(self):
        """Print generation summary"""
        print("\n" + "="*60)
        print("📊 SAMPLE DATA GENERATION COMPLETE")
        print("="*60)
        print(f"\n📁 Output Directory: {self.output_dir}")
        print(f"\n📈 Statistics:")
        print(f"   • Members:        {len(self.members):,}")
        print(f"   • Providers:      {len(self.providers):,}")
        print(f"   • Claims:         {len(self.claims):,}")
        print(f"   • Journeys:       {len(self.journeys):,}")
        print(f"   • Journey Events: {len(self.journey_events):,}")
        print(f"   • TPAs:           {len(TPAS)}")
        
        print(f"\n📋 Claim Type Distribution:")
        for claim_type in CLAIM_TYPES:
            count = len([c for c in self.claims if c["claim_type"] == claim_type])
            pct = (count / len(self.claims)) * 100
            print(f"   • {claim_type:12} {count:6,} ({pct:5.1f}%)")
            
        print(f"\n🗺️  Journey Type Distribution:")
        for journey_type in JOURNEY_TYPES:
            count = len([j for j in self.journeys if j["journey_type"] == journey_type])
            if count > 0:
                pct = (count / len(self.journeys)) * 100
                print(f"   • {journey_type:30} {count:4,} ({pct:5.1f}%)")
        
        print(f"\n💰 Financial Summary:")
        total_billed = sum(c["billed_amount"] for c in self.claims)
        total_paid = sum(c["paid_amount"] for c in self.claims)
        print(f"   • Total Billed:   ${total_billed:,.2f}")
        print(f"   • Total Paid:     ${total_paid:,.2f}")
        print(f"   • Discount Rate:  {((total_billed - total_paid) / total_billed * 100):.1f}%")
        
        print("\n✅ Ready to upload to Snowflake!")
        print("="*60 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Generate sample data for Bordereau Processing Pipeline"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("./sample_data/output"),
        help="Output directory for CSV files (default: ./sample_data/output)"
    )
    parser.add_argument(
        "--num-claims",
        type=int,
        default=1000,
        help="Number of claims to generate (default: 1000)"
    )
    
    args = parser.parse_args()
    
    # Generate data
    generator = SampleDataGenerator(args.output_dir, args.num_claims)
    generator.generate_all()


if __name__ == "__main__":
    main()
