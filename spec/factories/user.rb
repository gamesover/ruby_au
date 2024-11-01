FactoryBot.define do
  factory :user do
    sequence :full_name do |n|
      "full_name_#{n}"
    end
    sequence :email do |n|
      "user#{n}@example.com"
    end

    password { "password" }
    confirmed_at { 1.minute.ago }
    address { '42 Wallaby Way, Sydney' }
    visible { true }
    skip_subscriptions { true }

    trait :visible do
      visible { true }
    end
    trait :invisible do
      visible { false }
    end

    trait :committee do
      committee { true }
    end

    after(:create) do |user, _evaluator|
      if user.confirmed_at
        user.memberships.create(
          joined_at: Time.current,
          left_at: (user.deactivated_at ? 1.minute.ago : nil)
        )
      end
    end
  end
end
