"""
step 4 - postgres seeder
need at least 100k audit rows and 50k trips
insert riders/vehicles first, then trips
dont give one rider two REQUESTED/IN_TRANSIT trips
vehicle_id is required
better to update wallet_balance so the trigger writes the audit rows
"""


def main():
    raise NotImplementedError("seeder not done yet")


if __name__ == "__main__":
    main()
